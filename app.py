import os
import uuid
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


@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


@app.route('/usuarios/cadastro', methods=['POST'])
def cadastrar_usuario():
    dados = request.json

    nome = str(dados.get('nome', '')).strip()
    email = str(dados.get('email', '')).strip().lower()
    senha = str(dados.get('senha', '')).strip()

    if not nome or not email or not senha:
        return jsonify({"erro": "Preencha nome, email e senha."}), 400

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("SELECT id FROM usuarios WHERE email = %s", (email,))
        usuario_existente = cursor.fetchone()

        if usuario_existente:
            cursor.close()
            conexao.close()
            return jsonify({"erro": "Este email já está cadastrado."}), 400

        senha_hash = generate_password_hash(senha)

        cursor.execute(
            """
            INSERT INTO usuarios (nome, email, senha)
            VALUES (%s, %s, %s)
            """,
            (nome, email, senha_hash)
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
            "SELECT id, nome, email, senha FROM usuarios WHERE email = %s",
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
                COUNT(cur.id) AS total_curtidas,
                CASE 
                    WHEN SUM(CASE WHEN cur.usuario_id = %s THEN 1 ELSE 0 END) > 0 
                    THEN 1 
                    ELSE 0 
                END AS curtido_pelo_usuario
            FROM carros c
            LEFT JOIN curtidas cur ON c.id = cur.carro_id
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
                c.historia
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
                tipo_suspensao, aro_roda, foto_url, historia
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
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
            historia
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
                historia=%s
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
                usuarios.nome AS nome_usuario
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

@app.route('/usuarios/<int:id>', methods=['GET'])
def buscar_usuario(id):
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("""
            SELECT 
                id,
                nome,
                criado_em
            FROM usuarios
            WHERE id = %s
        """, (id,))

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
    
@app.route('/usuarios/<int:id>/carros', methods=['GET'])
def listar_carros_usuario(id):
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        cursor.execute("""
            SELECT 
                id,
                modelo,
                ano,
                cor,
                aro_roda,
                tipo_suspensao,
                foto_url
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

if __name__ == '__main__':
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)

    debug_mode = os.getenv("DEBUG") == "True"

    print("SERVIÇO DA GARAGEM LIGADO NA PORTA 5000!")
    app.run(debug=debug_mode)