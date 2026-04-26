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
    filtro_usuario = request.args.get('usuario_id', '')

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)

        sql = """
            SELECT id, usuario_id, nome_dono, modelo, ano, cor, placa,
                   tipo_suspensao, aro_roda, foto_url, historia
            FROM carros
            WHERE 1=1
        """
        valores = []

        if filtro_modelo:
            sql += " AND modelo LIKE %s"
            valores.append(f"%{filtro_modelo}%")

        if filtro_suspensao:
            sql += " AND tipo_suspensao LIKE %s"
            valores.append(filtro_suspensao)

        if filtro_aro:
            sql += " AND aro_roda = %s"
            valores.append(filtro_aro)

        if filtro_usuario:
            sql += " AND usuario_id = %s"
            valores.append(filtro_usuario)

        sql += " ORDER BY id DESC"

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
        return jsonify({"erro": "Usuário não informado. Faça login novamente."}), 400

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
                tipo_suspensao, aro_roda, foto_url, historia, senha_edicao
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NULL)
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
        return jsonify({"erro": "Usuário não informado. Faça login novamente."}), 400

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
        return jsonify({"erro": "Usuário não informado. Faça login novamente."}), 400

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


if __name__ == '__main__':
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)

    debug_mode = os.getenv("DEBUG") == "True"

    print("SERVIÇO DA GARAGEM LIGADO NA PORTA 5000!")
    app.run(debug=debug_mode)