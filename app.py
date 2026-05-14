import os
import uuid
import time
import re
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import mysql.connector
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = 'uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}

db_config = {
    'host': os.getenv('DB_HOST'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_NAME')
}


def allowed_file(filename):
    return (
        '.' in filename and
        filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
    )


def salvar_imagem(foto):
    if not foto or foto.filename == "":
        return ""

    if not allowed_file(foto.filename):
        raise ValueError("Formato de imagem inválido. Use PNG, JPG, JPEG ou WEBP.")

    filename = secure_filename(foto.filename)
    extensao = filename.rsplit('.', 1)[1].lower()
    nome_unico = f"{uuid.uuid4().hex}.{extensao}"

    caminho = os.path.join(app.config['UPLOAD_FOLDER'], nome_unico)
    foto.save(caminho)

    return nome_unico


def usuario_existe(cursor, usuario_id):
    cursor.execute("SELECT id FROM usuarios WHERE id = %s", (usuario_id,))
    return cursor.fetchone() is not None

def validar_username(username):
    if not username:
        return "Preencha o username."

    if len(username) < 3 or len(username) > 30:
        return "O username deve ter entre 3 e 30 caracteres."

    if not re.fullmatch(r"[a-z0-9._]+", username):
        return "O username deve conter apenas letras minúsculas, números, ponto e underline."

    return None

def gerar_slug(texto):
    slug = texto.strip().lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'\s+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


@app.route('/usuarios/cadastro', methods=['POST'])
def cadastrar_usuario():
    dados = request.json

    nome = str(dados.get('nome', '')).strip()
    username = str(dados.get('username', '')).strip().lower()
    email = str(dados.get('email', '')).strip().lower()
    senha = str(dados.get('senha', '')).strip()

    if not nome or not username or not email or not senha:
        return jsonify({"erro": "Preencha nome, username, email e senha."}), 400

    erro_username = validar_username(username)

    if erro_username:
        return jsonify({"erro": erro_username}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("SELECT id FROM usuarios WHERE email = %s", (email,))
        usuario_existente = cursor.fetchone()

        if usuario_existente:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Este email já está cadastrado."}), 400
        
        cursor.execute("SELECT id FROM usuarios WHERE username = %s", (username,))
        username_existente = cursor.fetchone()

        if username_existente:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Este username já está em uso."}), 400

        senha_hash = generate_password_hash(senha)

        cursor.execute(
            """
            INSERT INTO usuarios (nome, username, email, senha)
            VALUES (%s, %s, %s, %s)
            """,
            (nome, username, email, senha_hash)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Usuário cadastrado com sucesso!"}), 201

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@app.route('/usuarios/login', methods=['POST'])
def login_usuario():
    dados = request.json

    email = str(dados.get('email', '')).strip().lower()
    senha = str(dados.get('senha', '')).strip()

    if not email or not senha:
        return jsonify({"erro": "Preencha email e senha."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute(
            "SELECT id, nome, username, email, senha FROM usuarios WHERE email = %s",
            (email,)
        )

        usuario = cursor.fetchone()

        cursor.close()
        conexao.close()

        if not usuario:
            return jsonify({"erro": "Usuário não encontrado."}), 404

        if not check_password_hash(usuario['senha'], senha):
            return jsonify({"erro": "Senha incorreta."}), 403

        return jsonify({
            "mensagem": "Login realizado com sucesso!",
            "usuario": {
                "id": usuario['id'],
                "nome": usuario['nome'],
                "username": usuario['username'],
                "email": usuario['email']
            }
        }), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@app.route('/carros', methods=['GET'])
def listar_carros():
    filtro_modelo = request.args.get('modelo', '')
    filtro_suspensao = request.args.get('suspensao', '')
    filtro_aro = request.args.get('aro', '')
    usuario_id = request.args.get('usuario_id', '')

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        sql = """
            SELECT 
                c.id,
                c.usuario_id,
                c.nome_dono,
                c.modelo,
                c.ano,
                c.cor,
                c.placa,
                c.tipo_suspensao,
                c.aro_roda,
                c.foto_url,
                c.historia,
                c.motor,
                c.cambio,
                c.combustivel,
                c.potencia_estimada,
                c.preparacao,
                c.status_projeto,
                COUNT(DISTINCT cur.id) AS total_curtidas,
                COUNT(DISTINCT com.id) AS total_comentarios,
                CASE 
                    WHEN SUM(CASE WHEN cur.usuario_id = %s THEN 1 ELSE 0 END) > 0 
                    THEN 1 
                    ELSE 0 
                END AS curtido_pelo_usuario
            FROM carros c
            LEFT JOIN curtidas cur ON c.id = cur.carro_id
            LEFT JOIN comentarios com ON c.id = com.carro_id
            WHERE 1=1
        """

        valores = [usuario_id if usuario_id else 0]

        if filtro_modelo:
            sql += " AND c.modelo LIKE %s"
            valores.append(f"%{filtro_modelo}%")

        if filtro_suspensao:
            sql += " AND c.tipo_suspensao LIKE %s"
            valores.append(filtro_suspensao)

        if filtro_aro:
            sql += " AND c.aro_roda = %s"
            valores.append(filtro_aro)

        sql += """
            GROUP BY 
                c.id,
                c.usuario_id,
                c.nome_dono,
                c.modelo,
                c.ano,
                c.cor,
                c.placa,
                c.tipo_suspensao,
                c.aro_roda,
                c.foto_url,
                c.historia,
                c.motor,
                c.cambio,
                c.combustivel,
                c.potencia_estimada,
                c.preparacao,
                c.status_projeto
            ORDER BY c.id DESC
        """

        cursor.execute(sql, tuple(valores))
        meus_carros = cursor.fetchall()

        cursor.close()
        conexao.close()

        return jsonify(meus_carros)

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@app.route('/carros', methods=['POST'])
def cadastrar_carro():
    dados = request.form
    historia = dados.get('historia', '')
    usuario_id = dados.get('usuario_id')

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        foto = request.files.get('foto')
        nome_foto = salvar_imagem(foto)

        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        sql = """
            INSERT INTO carros (
                usuario_id, nome_dono, modelo, ano, cor, placa,
                tipo_suspensao, aro_roda, foto_url, historia,
                motor, cambio, combustivel, potencia_estimada, preparacao, status_projeto
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """

        cursor.execute(sql, (
            usuario_id,
            dados['nome_dono'],
            dados['modelo'],
            dados['ano'],
            dados['cor'],
            dados['placa'],
            dados['tipo_suspensao'],
            dados['aro_roda'],
            nome_foto,
            historia,
            dados.get('motor', ''),
            dados.get('cambio', ''),
            dados.get('combustivel', ''),
            dados.get('potencia_estimada', ''),
            dados.get('preparacao', ''),
            dados.get('status_projeto', '')
        ))

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Projeto salvo!"}), 201

    except ValueError as e:
        return jsonify({"erro": str(e)}), 400

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@app.route('/carros/<int:id>', methods=['PUT'])
def editar_carro(id):
    dados = request.form
    historia = dados.get('historia', '')
    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("SELECT usuario_id, foto_url FROM carros WHERE id = %s", (id,))
        carro = cursor.fetchone()

        if not carro:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Não achei o carro"}), 404

        if str(carro['usuario_id']) != usuario_id:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você não tem permissão para editar este projeto."}), 403

        foto = request.files.get('foto')
        nome_foto = carro['foto_url']

        if foto and foto.filename != "":
            nome_foto = salvar_imagem(foto)

        sql = """
            UPDATE carros
            SET nome_dono=%s,
                modelo=%s,
                ano=%s,
                cor=%s,
                placa=%s,
                tipo_suspensao=%s,
                aro_roda=%s,
                foto_url=%s,
                historia=%s,
                motor=%s,
                cambio=%s,
                combustivel=%s,
                potencia_estimada=%s,
                preparacao=%s,
                status_projeto=%s
            WHERE id=%s
        """

        cursor.execute(sql, (
            dados['nome_dono'],
            dados['modelo'],
            dados['ano'],
            dados['cor'],
            dados['placa'],
            dados['tipo_suspensao'],
            dados['aro_roda'],
            nome_foto,
            historia,
            dados.get('motor', ''),
            dados.get('cambio', ''),
            dados.get('combustivel', ''),
            dados.get('potencia_estimada', ''),
            dados.get('preparacao', ''),
            dados.get('status_projeto', ''),
            id
        ))

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Atualizado!"})

    except ValueError as e:
        return jsonify({"erro": str(e)}), 400

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@app.route('/carros/<int:id>', methods=['DELETE'])
def excluir_carro(id):
    dados = request.json
    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("SELECT usuario_id FROM carros WHERE id = %s", (id,))
        carro = cursor.fetchone()

        if not carro:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Não achei o carro"}), 404

        if str(carro['usuario_id']) != usuario_id:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você não tem permissão para remover este projeto."}), 403

        cursor.execute("DELETE FROM carros WHERE id = %s", (id,))
        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Removido!"}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@app.route('/carros/<int:id>/curtir', methods=['POST'])
def curtir_carro(id):
    dados = request.json
    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute("SELECT id FROM carros WHERE id = %s", (id,))
        carro = cursor.fetchone()

        if not carro:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Projeto não encontrado."}), 404

        cursor.execute(
            "SELECT id FROM curtidas WHERE usuario_id = %s AND carro_id = %s",
            (usuario_id, id)
        )
        curtida = cursor.fetchone()

        if curtida:
            cursor.execute(
                "DELETE FROM curtidas WHERE usuario_id = %s AND carro_id = %s",
                (usuario_id, id)
            )
            acao = "descurtido"
        else:
            cursor.execute(
                "INSERT INTO curtidas (usuario_id, carro_id) VALUES (%s, %s)",
                (usuario_id, id)
            )
            acao = "curtido"

        conexao.commit()

        cursor.execute(
            "SELECT COUNT(*) AS total_curtidas FROM curtidas WHERE carro_id = %s",
            (id,)
        )
        resultado = cursor.fetchone()

        cursor.close()
        conexao.close()

        return jsonify({
            "mensagem": f"Projeto {acao} com sucesso!",
            "acao": acao,
            "total_curtidas": resultado['total_curtidas']
        }), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/carros/<int:id>/comentarios', methods=['GET'])
def listar_comentarios(id):
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("SELECT id FROM carros WHERE id = %s", (id,))
        carro = cursor.fetchone()

        if not carro:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Projeto não encontrado."}), 404

        cursor.execute(
            """
            SELECT 
                comentarios.id,
                comentarios.texto,
                comentarios.criado_em,
                usuarios.id AS usuario_id,
                usuarios.nome AS nome_usuario,
                usuarios.username AS username_usuario
            FROM comentarios
            INNER JOIN usuarios ON comentarios.usuario_id = usuarios.id
            WHERE comentarios.carro_id = %s
            ORDER BY comentarios.criado_em DESC
            """,
            (id,)
        )

        comentarios = cursor.fetchall()

        cursor.close()
        conexao.close()

        return jsonify(comentarios), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


@app.route('/carros/<int:id>/comentarios', methods=['POST'])
def cadastrar_comentario(id):
    dados = request.json

    usuario_id = str(dados.get('usuario_id', '')).strip()
    texto = str(dados.get('texto', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    if not texto:
        return jsonify({"erro": "Digite um comentário."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute("SELECT id FROM carros WHERE id = %s", (id,))
        carro = cursor.fetchone()

        if not carro:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Projeto não encontrado."}), 404

        cursor.execute(
            """
            INSERT INTO comentarios (usuario_id, carro_id, texto)
            VALUES (%s, %s, %s)
            """,
            (usuario_id, id, texto)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Comentário publicado com sucesso!"}), 201

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    
@app.route('/comentarios/<int:id>', methods=['DELETE'])
def excluir_comentario(id):
    dados = request.json
    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute(
            """
            SELECT id, usuario_id
            FROM comentarios
            WHERE id = %s
            """,
            (id,)
        )

        comentario = cursor.fetchone()

        if not comentario:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Comentário não encontrado."}), 404

        if str(comentario['usuario_id']) != usuario_id:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você não tem permissão para remover este comentário."}), 403

        cursor.execute(
            "DELETE FROM comentarios WHERE id = %s",
            (id,)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Comentário removido com sucesso!"}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/usuarios/<int:id>', methods=['GET'])
def buscar_usuario(id):
    usuario_logado_id = request.args.get('usuario_logado_id')

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("""
            SELECT 
                u.id,
                u.nome,
                u.username,
                u.criado_em,
                u.avatar_url,
                u.bio,
                COUNT(DISTINCT s1.id) AS total_seguidores,
                COUNT(DISTINCT s2.id) AS total_seguindo,
                CASE
                    WHEN COUNT(DISTINCT s3.id) > 0
                    THEN 1
                    ELSE 0
                END AS seguido_pelo_usuario
            FROM usuarios u
            LEFT JOIN seguidores s1 ON u.id = s1.seguido_id
            LEFT JOIN seguidores s2 ON u.id = s2.seguidor_id
            LEFT JOIN seguidores s3 ON u.id = s3.seguido_id AND s3.seguidor_id = %s
            WHERE u.id = %s
            GROUP BY u.id
        """, (
            usuario_logado_id if usuario_logado_id else 0,
            id
        ))

        usuario = cursor.fetchone()

        if not usuario:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário não encontrado."}), 404

        cursor.execute("""
            SELECT COUNT(*) AS total_projetos
            FROM carros
            WHERE usuario_id = %s
        """, (id,))

        total = cursor.fetchone()

        usuario['total_projetos'] = total['total_projetos']

        cursor.close()
        conexao.close()

        return jsonify(usuario), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/usuarios/<int:id>/seguir', methods=['POST'])
def seguir_usuario(id):
    dados = request.json
    seguidor_id = str(dados.get('usuario_id', '')).strip()

    if not seguidor_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    if str(id) == seguidor_id:
        return jsonify({"erro": "Você não pode seguir a si mesmo."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, seguidor_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        if not usuario_existe(cursor, id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Perfil não encontrado."}), 404

        cursor.execute(
            """
            INSERT INTO seguidores (seguidor_id, seguido_id)
            VALUES (%s, %s)
            """,
            (seguidor_id, id)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Usuário seguido com sucesso!"}), 201

    except mysql.connector.IntegrityError:
        try:
            cursor.close()
            conexao.close()
        except:
            pass

        return jsonify({"erro": "Você já segue este usuário."}), 409

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/usuarios/<int:id>/seguir', methods=['DELETE'])
def deixar_de_seguir_usuario(id):
    dados = request.json
    seguidor_id = str(dados.get('usuario_id', '')).strip()

    if not seguidor_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    if str(id) == seguidor_id:
        return jsonify({"erro": "Você não pode deixar de seguir a si mesmo."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, seguidor_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute(
            """
            DELETE FROM seguidores
            WHERE seguidor_id = %s AND seguido_id = %s
            """,
            (seguidor_id, id)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Usuário deixou de ser seguido."}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    
@app.route('/usuarios/<int:id>', methods=['PUT'])
def atualizar_usuario(id):
    dados = request.json
    usuario_logado_id = str(dados.get('usuario_id', '')).strip()
    avatar_url = str(dados.get('avatar_url', '')).strip()
    bio = str(dados.get('bio', '')).strip()

    if not usuario_logado_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    if str(id) != usuario_logado_id:
        return jsonify({"erro": "Você não tem permissão para editar este perfil."}), 403

    if len(avatar_url) > 1000:
        return jsonify({"erro": "URL do avatar muito longa."}), 400

    if len(bio) > 280:
        return jsonify({"erro": "A bio deve ter no máximo 280 caracteres."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_logado_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute(
            """
            UPDATE usuarios
            SET avatar_url = %s,
                bio = %s
            WHERE id = %s
            """,
            (
                avatar_url if avatar_url else None,
                bio if bio else None,
                id
            )
        )

        conexao.commit()

        cursor.execute(
            """
            SELECT id, nome, username, criado_em, avatar_url, bio
            FROM usuarios
            WHERE id = %s
            """,
            (id,)
        )

        usuario = cursor.fetchone()

        cursor.close()
        conexao.close()

        return jsonify(usuario), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/usuarios/<int:id>/avatar', methods=['POST'])
def upload_avatar(id):
    usuario_id = request.form.get('usuario_id')

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    if str(usuario_id) != str(id):
        return jsonify({"erro": "Sem permissão."}), 403

    if 'arquivo' not in request.files:
        return jsonify({"erro": "Arquivo não enviado."}), 400

    arquivo = request.files['arquivo']

    if arquivo.filename == '':
        return jsonify({"erro": "Arquivo inválido."}), 400

    try:
        extensoes_permitidas = ['png', 'jpg', 'jpeg', 'webp']

        nome = secure_filename(arquivo.filename)
        extensao = nome.rsplit('.', 1)[-1].lower()

        if extensao not in extensoes_permitidas:
            return jsonify({"erro": "Formato de imagem não permitido."}), 400

        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor()

        if not usuario_existe(cursor, id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 404

        nome_arquivo = f"user_{id}_{int(time.time())}.{extensao}"

        pasta_avatars = os.path.join('uploads', 'avatars')
        os.makedirs(pasta_avatars, exist_ok=True)

        caminho = os.path.join(pasta_avatars, nome_arquivo)

        arquivo.save(caminho)

        cursor.execute(
            "UPDATE usuarios SET avatar_url = %s WHERE id = %s",
            (f"avatars/{nome_arquivo}", id)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({
            "mensagem": "Avatar atualizado com sucesso!",
            "avatar_url": f"avatars/{nome_arquivo}"
        }), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/usuarios/<int:id>/carros', methods=['GET'])
def listar_carros_usuario(id):
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("""
            SELECT 
                id,
                usuario_id,
                nome_dono,
                modelo,
                ano,
                cor,
                placa,
                aro_roda,
                tipo_suspensao,
                foto_url,
                historia,
                motor,
                cambio,
                combustivel,
                potencia_estimada,
                preparacao,
                status_projeto
            FROM carros
            WHERE usuario_id = %s
            ORDER BY id DESC
        """, (id,))

        carros = cursor.fetchall()

        cursor.close()
        conexao.close()

        return jsonify(carros), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    
@app.route('/usuarios/<int:id>/clube', methods=['GET'])
def buscar_clube_usuario(id):
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário não encontrado."}), 404

        cursor.execute(
            """
            SELECT 
                c.id,
                c.nome,
                c.slug,
                c.descricao,
                c.dono_id,
                c.criado_em,
                dono.nome AS nome_dono,
                dono.username AS username_dono,
                COUNT(DISTINCT todos_membros.id) AS total_membros
            FROM membros_clube membro_usuario
            INNER JOIN clubes c ON membro_usuario.clube_id = c.id
            INNER JOIN usuarios dono ON c.dono_id = dono.id
            LEFT JOIN membros_clube todos_membros ON c.id = todos_membros.clube_id
            WHERE membro_usuario.usuario_id = %s
            GROUP BY 
                c.id,
                c.nome,
                c.slug,
                c.descricao,
                c.dono_id,
                c.criado_em,
                dono.nome,
                dono.username
            LIMIT 1
            """,
            (id,)
        )

        clube = cursor.fetchone()

        if not clube:
            cursor.close()
            conexao.close()
            return jsonify(None), 200

        cursor.execute(
            """
            SELECT 
                u.id,
                u.nome,
                u.username,
                u.avatar_url,
                m.criado_em
            FROM membros_clube m
            INNER JOIN usuarios u ON m.usuario_id = u.id
            WHERE m.clube_id = %s
            ORDER BY m.criado_em ASC
            """,
            (clube['id'],)
        )

        membros = cursor.fetchall()
        clube['membros'] = membros

        cursor.close()
        conexao.close()

        return jsonify(clube), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/usuarios/<int:id>/pedidos-clube', methods=['GET'])
def listar_pedidos_clube_usuario(id):
    status = request.args.get('status', 'pendente')

    status_permitidos = ['pendente', 'aprovado', 'recusado', 'todos']

    if status not in status_permitidos:
        return jsonify({"erro": "Status inválido."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário não encontrado."}), 404

        sql = """
            SELECT 
                p.id,
                p.usuario_id,
                p.clube_id,
                p.status,
                p.criado_em,
                c.nome AS nome_clube,
                c.slug,
                c.descricao,
                c.dono_id,
                dono.username AS username_dono,
                COUNT(DISTINCT membros.id) AS total_membros
            FROM pedidos_clube p
            INNER JOIN clubes c ON p.clube_id = c.id
            INNER JOIN usuarios dono ON c.dono_id = dono.id
            LEFT JOIN membros_clube membros ON c.id = membros.clube_id
            WHERE p.usuario_id = %s
        """

        valores = [id]

        if status != 'todos':
            sql += " AND p.status = %s"
            valores.append(status)

        sql += """
            GROUP BY 
                p.id,
                p.usuario_id,
                p.clube_id,
                p.status,
                p.criado_em,
                c.nome,
                c.slug,
                c.descricao,
                c.dono_id,
                dono.username
            ORDER BY p.criado_em DESC
        """

        cursor.execute(sql, tuple(valores))
        pedidos = cursor.fetchall()

        cursor.close()
        conexao.close()

        return jsonify(pedidos), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    
@app.route('/clubes', methods=['POST'])
def criar_clube():
    dados = request.json

    usuario_id = str(dados.get('usuario_id', '')).strip()
    nome = str(dados.get('nome', '')).strip()
    descricao = str(dados.get('descricao', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    if not nome:
        return jsonify({"erro": "Informe o nome do clube."}), 400

    if len(nome) < 3 or len(nome) > 100:
        return jsonify({"erro": "O nome do clube deve ter entre 3 e 100 caracteres."}), 400

    if len(descricao) > 500:
        return jsonify({"erro": "A descrição deve ter no máximo 500 caracteres."}), 400

    slug_base = gerar_slug(nome)

    if not slug_base:
        return jsonify({"erro": "Nome de clube inválido."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute(
            "SELECT id FROM membros_clube WHERE usuario_id = %s",
            (usuario_id,)
        )
        membro_existente = cursor.fetchone()

        if membro_existente:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você já participa de um clube."}), 400

        slug = slug_base
        contador = 1

        while True:
            cursor.execute("SELECT id FROM clubes WHERE slug = %s", (slug,))
            clube_existente = cursor.fetchone()

            if not clube_existente:
                break

            contador += 1
            slug = f"{slug_base}-{contador}"

        cursor.execute(
            """
            INSERT INTO clubes (nome, slug, descricao, dono_id)
            VALUES (%s, %s, %s, %s)
            """,
            (
                nome,
                slug,
                descricao if descricao else None,
                usuario_id
            )
        )

        clube_id = cursor.lastrowid

        cursor.execute(
            """
            INSERT INTO membros_clube (usuario_id, clube_id)
            VALUES (%s, %s)
            """,
            (usuario_id, clube_id)
        )

        conexao.commit()

        cursor.execute(
            """
            SELECT 
                c.id,
                c.nome,
                c.slug,
                c.descricao,
                c.dono_id,
                c.criado_em,
                u.nome AS nome_dono,
                u.username AS username_dono,
                COUNT(m.id) AS total_membros
            FROM clubes c
            INNER JOIN usuarios u ON c.dono_id = u.id
            LEFT JOIN membros_clube m ON c.id = m.clube_id
            WHERE c.id = %s
            GROUP BY c.id
            """,
            (clube_id,)
        )

        clube = cursor.fetchone()

        cursor.close()
        conexao.close()

        return jsonify({
            "mensagem": "Clube criado com sucesso!",
            "clube": clube
        }), 201

    except mysql.connector.IntegrityError:
        try:
            cursor.close()
            conexao.close()
        except:
            pass

        return jsonify({"erro": "Não foi possível criar o clube. Verifique se você já participa de um clube."}), 409

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/clubes', methods=['GET'])
def listar_clubes():
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT 
                c.id,
                c.nome,
                c.slug,
                c.descricao,
                c.dono_id,
                c.criado_em,
                u.nome AS nome_dono,
                u.username AS username_dono,
                COUNT(m.id) AS total_membros
            FROM clubes c
            INNER JOIN usuarios u ON c.dono_id = u.id
            LEFT JOIN membros_clube m ON c.id = m.clube_id
            GROUP BY c.id
            ORDER BY c.id DESC
            """
        )

        clubes = cursor.fetchall()

        cursor.close()
        conexao.close()

        return jsonify(clubes), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/clubes/<int:id>', methods=['GET'])
def buscar_clube(id):
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT 
                c.id,
                c.nome,
                c.slug,
                c.descricao,
                c.dono_id,
                c.criado_em,
                u.nome AS nome_dono,
                u.username AS username_dono,
                COUNT(m.id) AS total_membros
            FROM clubes c
            INNER JOIN usuarios u ON c.dono_id = u.id
            LEFT JOIN membros_clube m ON c.id = m.clube_id
            WHERE c.id = %s
            GROUP BY c.id
            """,
            (id,)
        )

        clube = cursor.fetchone()

        if not clube:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Clube não encontrado."}), 404

        cursor.execute(
            """
            SELECT 
                u.id,
                u.nome,
                u.username,
                u.avatar_url,
                m.criado_em
            FROM membros_clube m
            INNER JOIN usuarios u ON m.usuario_id = u.id
            WHERE m.clube_id = %s
            ORDER BY m.criado_em ASC
            """,
            (id,)
        )

        membros = cursor.fetchall()
        clube['membros'] = membros

        cursor.close()
        conexao.close()

        return jsonify(clube), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/clubes/<int:id>/carros', methods=['GET'])
def listar_carros_clube(id):
    usuario_id = request.args.get('usuario_id', '')

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("SELECT id FROM clubes WHERE id = %s", (id,))
        clube = cursor.fetchone()

        if not clube:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Equipe não encontrada."}), 404

        cursor.execute(
            """
            SELECT
                c.id,
                c.usuario_id,
                c.nome_dono,
                c.modelo,
                c.ano,
                c.cor,
                c.placa,
                c.tipo_suspensao,
                c.aro_roda,
                c.foto_url,
                c.historia,
                c.motor,
                c.cambio,
                c.combustivel,
                c.potencia_estimada,
                c.preparacao,
                c.status_projeto,
                u.nome AS nome_usuario,
                u.username AS username_usuario,
                COUNT(DISTINCT cur.id) AS total_curtidas,
                COUNT(DISTINCT com.id) AS total_comentarios,
                CASE
                    WHEN SUM(CASE WHEN cur.usuario_id = %s THEN 1 ELSE 0 END) > 0
                    THEN 1
                    ELSE 0
                END AS curtido_pelo_usuario
            FROM carros c
            INNER JOIN membros_clube mc ON c.usuario_id = mc.usuario_id
            INNER JOIN usuarios u ON c.usuario_id = u.id
            LEFT JOIN curtidas cur ON c.id = cur.carro_id
            LEFT JOIN comentarios com ON c.id = com.carro_id
            WHERE mc.clube_id = %s
            GROUP BY
                c.id,
                c.usuario_id,
                c.nome_dono,
                c.modelo,
                c.ano,
                c.cor,
                c.placa,
                c.tipo_suspensao,
                c.aro_roda,
                c.foto_url,
                c.historia,
                c.motor,
                c.cambio,
                c.combustivel,
                c.potencia_estimada,
                c.preparacao,
                c.status_projeto,
                u.nome,
                u.username
            ORDER BY c.id DESC
            """,
            (usuario_id if usuario_id else 0, id)
        )

        carros = cursor.fetchall()

        cursor.close()
        conexao.close()

        return jsonify(carros), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    
@app.route('/clubes/<int:id>/pedidos', methods=['POST'])
def pedir_entrada_clube(id):
    try:
        dados = request.get_json()

        if not dados:
            return jsonify({"erro": "Dados não enviados."}), 400

        usuario_id = dados.get('usuario_id')

        if not usuario_id:
            return jsonify({"erro": "Usuário não informado."}), 400

        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário não encontrado."}), 404

        cursor.execute(
            "SELECT id FROM clubes WHERE id = %s",
            (id,)
        )
        clube = cursor.fetchone()

        if not clube:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Equipe não encontrada."}), 404

        cursor.execute(
            "SELECT id FROM membros_clube WHERE usuario_id = %s LIMIT 1",
            (usuario_id,)
        )
        membro_existente = cursor.fetchone()

        if membro_existente:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você já participa de uma equipe."}), 400

        cursor.execute(
            """
            SELECT id 
            FROM pedidos_clube 
            WHERE usuario_id = %s 
              AND clube_id = %s 
              AND status = 'pendente'
            LIMIT 1
            """,
            (usuario_id, id)
        )
        pedido_existente = cursor.fetchone()

        if pedido_existente:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você já enviou um pedido para esta equipe."}), 400

        cursor.execute(
            """
            INSERT INTO pedidos_clube (usuario_id, clube_id, status)
            VALUES (%s, %s, 'pendente')
            """,
            (usuario_id, id)
        )

        conexao.commit()

        pedido_id = cursor.lastrowid

        cursor.close()
        conexao.close()

        return jsonify({
            "mensagem": "Pedido enviado com sucesso.",
            "pedido": {
                "id": pedido_id,
                "usuario_id": usuario_id,
                "clube_id": id,
                "status": "pendente"
            }
        }), 201

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/clubes/<int:id>/pedidos', methods=['DELETE'])
def cancelar_pedido_clube(id):
    dados = request.json or {}
    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute("SELECT id FROM clubes WHERE id = %s", (id,))
        clube = cursor.fetchone()

        if not clube:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Equipe não encontrada."}), 404

        cursor.execute(
            """
            SELECT id
            FROM pedidos_clube
            WHERE usuario_id = %s
              AND clube_id = %s
              AND status = 'pendente'
            LIMIT 1
            """,
            (usuario_id, id)
        )

        pedido = cursor.fetchone()

        if not pedido:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Pedido pendente não encontrado."}), 404

        cursor.execute(
            "DELETE FROM pedidos_clube WHERE id = %s",
            (pedido['id'],)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Pedido cancelado com sucesso."}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/clubes/<int:id>/pedidos', methods=['GET'])
def listar_pedidos_clube(id):
    usuario_id = request.args.get('usuario_id')

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário não encontrado."}), 404

        cursor.execute(
            "SELECT id, dono_id FROM clubes WHERE id = %s",
            (id,)
        )
        clube = cursor.fetchone()

        if not clube:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Equipe não encontrada."}), 404

        if str(clube['dono_id']) != str(usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você não tem permissão para ver os pedidos desta equipe."}), 403

        cursor.execute(
            """
            SELECT 
                p.id,
                p.usuario_id,
                p.clube_id,
                p.status,
                p.criado_em,
                u.nome,
                u.username,
                u.avatar_url
            FROM pedidos_clube p
            INNER JOIN usuarios u ON p.usuario_id = u.id
            WHERE p.clube_id = %s
              AND p.status = 'pendente'
            ORDER BY p.criado_em ASC
            """,
            (id,)
        )

        pedidos = cursor.fetchall()

        cursor.close()
        conexao.close()

        return jsonify(pedidos), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/pedidos-clube/<int:id>/aprovar', methods=['PUT'])
def aprovar_pedido_clube(id):
    dados = request.json

    if not dados:
        return jsonify({"erro": "Dados não enviados."}), 400

    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário não encontrado."}), 404

        cursor.execute(
            """
            SELECT 
                p.id,
                p.usuario_id,
                p.clube_id,
                p.status,
                c.dono_id
            FROM pedidos_clube p
            INNER JOIN clubes c ON p.clube_id = c.id
            WHERE p.id = %s
            """,
            (id,)
        )

        pedido = cursor.fetchone()

        if not pedido:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Pedido não encontrado."}), 404

        if pedido['status'] != 'pendente':
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Este pedido já foi analisado."}), 400

        if str(pedido['dono_id']) != usuario_id:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você não tem permissão para aprovar este pedido."}), 403

        cursor.execute(
            "SELECT id FROM membros_clube WHERE usuario_id = %s LIMIT 1",
            (pedido['usuario_id'],)
        )
        membro_existente = cursor.fetchone()

        if membro_existente:
            cursor.execute(
                """
                UPDATE pedidos_clube
                SET status = 'recusado'
                WHERE id = %s
                """,
                (id,)
            )

            conexao.commit()

            cursor.close()
            conexao.close()

            return jsonify({
                "erro": "Este usuário já participa de uma equipe. O pedido foi recusado automaticamente."
            }), 400

        cursor.execute(
            """
            INSERT INTO membros_clube (usuario_id, clube_id)
            VALUES (%s, %s)
            """,
            (pedido['usuario_id'], pedido['clube_id'])
        )

        cursor.execute(
            """
            UPDATE pedidos_clube
            SET status = 'aprovado'
            WHERE id = %s
            """,
            (id,)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Pedido aprovado com sucesso."}), 200

    except mysql.connector.IntegrityError:
        try:
            conexao.rollback()
            cursor.close()
            conexao.close()
        except:
            pass

        return jsonify({"erro": "Não foi possível aprovar. O usuário já participa de uma equipe."}), 400

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/pedidos-clube/<int:id>/recusar', methods=['PUT'])
def recusar_pedido_clube(id):
    dados = request.json

    if not dados:
        return jsonify({"erro": "Dados não enviados."}), 400

    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário não encontrado."}), 404

        cursor.execute(
            """
            SELECT 
                p.id,
                p.usuario_id,
                p.clube_id,
                p.status,
                c.dono_id
            FROM pedidos_clube p
            INNER JOIN clubes c ON p.clube_id = c.id
            WHERE p.id = %s
            """,
            (id,)
        )

        pedido = cursor.fetchone()

        if not pedido:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Pedido não encontrado."}), 404

        if pedido['status'] != 'pendente':
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Este pedido já foi analisado."}), 400

        if str(pedido['dono_id']) != usuario_id:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você não tem permissão para recusar este pedido."}), 403
        
        cursor.execute(
            """
            DELETE FROM pedidos_clube
            WHERE usuario_id = %s
            AND clube_id = %s
            AND status = 'recusado'
            AND id <> %s
            """,
            (pedido['usuario_id'], pedido['clube_id'], id)
        )

        cursor.execute(
            """
            UPDATE pedidos_clube
            SET status = 'recusado'
            WHERE id = %s
            """,
            (id,)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Pedido recusado com sucesso."}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/clubes/<int:clube_id>/entrar', methods=['POST'])
def entrar_clube(clube_id):
    dados = request.json
    usuario_id = str(dados.get('usuario_id', '')).strip()

    if not usuario_id:
        return jsonify({"erro": "Usuário não informado."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        if not usuario_existe(cursor, usuario_id):
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Usuário inválido."}), 403

        cursor.execute(
            "SELECT id FROM membros_clube WHERE usuario_id = %s",
            (usuario_id,)
        )
        membro = cursor.fetchone()

        if membro:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Você já participa de uma equipe."}), 400

        cursor.execute(
            "SELECT id FROM clubes WHERE id = %s",
            (clube_id,)
        )
        clube = cursor.fetchone()

        if not clube:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Equipe não encontrada."}), 404

        cursor.execute(
            """
            INSERT INTO membros_clube (usuario_id, clube_id)
            VALUES (%s, %s)
            """,
            (usuario_id, clube_id)
        )

        conexao.commit()

        cursor.close()
        conexao.close()

        return jsonify({"mensagem": "Você entrou na equipe!"}), 200

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

if __name__ == '__main__':
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)

    debug_mode = os.getenv("DEBUG") == "True"

    print("SERVIÇO DA GARAGEM LIGADO NA PORTA 5000!")
    app.run(debug=debug_mode)