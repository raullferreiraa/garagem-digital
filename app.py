import os
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import mysql.connector
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = 'uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': '', 
    'database': 'garagem_digital'
}

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/carros', methods=['GET'])
def listar_carros():
    filtro_modelo = request.args.get('modelo', '')
    filtro_suspensao = request.args.get('suspensao', '')
    filtro_aro = request.args.get('aro', '')
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)
        sql = "SELECT id, nome_dono, modelo, ano, cor, placa, tipo_suspensao, aro_roda, foto_url FROM carros WHERE 1=1"
        valores = []
        if filtro_modelo:
            sql += " AND modelo LIKE %s"; valores.append(f"%{filtro_modelo}%") 
        if filtro_suspensao:
            sql += " AND tipo_suspensao LIKE %s"; valores.append(filtro_suspensao)
        if filtro_aro:
            sql += " AND aro_roda = %s"; valores.append(filtro_aro)
        cursor.execute(sql, tuple(valores))
        meus_carros = cursor.fetchall()
        cursor.close(); conexao.close()
        return jsonify(meus_carros)
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/carros', methods=['POST'])
def cadastrar_carro():
    dados = request.form
    senha = dados.get('senha_edicao')
    if not senha or senha.strip() == "":
        return jsonify({"erro": "Defina uma senha!"}), 400
    
    foto = request.files.get('foto')
    nome_foto = ""
    if foto:
        nome_foto = secure_filename(foto.filename)
        foto.save(os.path.join(app.config['UPLOAD_FOLDER'], nome_foto))

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor()
        sql = "INSERT INTO carros (nome_dono, modelo, ano, cor, placa, tipo_suspensao, aro_roda, foto_url, senha_edicao) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)"
        cursor.execute(sql, (dados['nome_dono'], dados['modelo'], dados['ano'], dados['cor'], dados['placa'], dados['tipo_suspensao'], dados['aro_roda'], nome_foto, senha))
        conexao.commit()
        cursor.close(); conexao.close()
        return jsonify({"mensagem": "Projeto salvo!"}), 201
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/carros/<int:id>', methods=['PUT'])
def editar_carro(id):
    dados = request.form
    senha_cliente = str(dados.get('senha_edicao', '')).strip()

    print(f"\n>>> TENTATIVA DE EDIÇÃO NO ID: {id}")
    print(f">>> SENHA QUE VEIO DO SITE: '{senha_cliente}'")

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)
        cursor.execute("SELECT senha_edicao, foto_url FROM carros WHERE id = %s", (id,))
        carro = cursor.fetchone()

        if not carro:
            return jsonify({"erro": "Não achei o carro"}), 404

        senha_no_banco = str(carro['senha_edicao']).strip()
        print(f">>> SENHA NO BANCO: '{senha_no_banco}'")

        # VALIDAÇÃO REAL
        if senha_no_banco != senha_cliente:
            print(">>> BLOQUEADO: Senhas não batem!")
            cursor.close(); conexao.close()
            return jsonify({"erro": "Senha incorreta!"}), 403

        print(">>> SUCESSO: Senhas batem. Atualizando...")
        foto = request.files.get('foto')
        nome_foto = carro['foto_url']
        if foto:
            nome_foto = secure_filename(foto.filename)
            foto.save(os.path.join(app.config['UPLOAD_FOLDER'], nome_foto))

        sql = "UPDATE carros SET nome_dono=%s, modelo=%s, ano=%s, cor=%s, placa=%s, tipo_suspensao=%s, aro_roda=%s, foto_url=%s WHERE id=%s"
        cursor.execute(sql, (dados['nome_dono'], dados['modelo'], dados['ano'], dados['cor'], dados['placa'], dados['tipo_suspensao'], dados['aro_roda'], nome_foto, id))
        conexao.commit()
        cursor.close(); conexao.close()
        return jsonify({"mensagem": "Atualizado!"})
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/carros/<int:id>', methods=['DELETE'])
def excluir_carro(id):
    dados = request.json
    senha_cliente = dados.get('senha')
    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor(dictionary=True)
        cursor.execute("SELECT senha_edicao FROM carros WHERE id = %s", (id,))
        carro = cursor.fetchone()
        if carro and str(carro['senha_edicao']).strip() == str(senha_cliente).strip():
            cursor.execute("DELETE FROM carros WHERE id = %s", (id,))
            conexao.commit()
            cursor.close(); conexao.close()
            return jsonify({"mensagem": "Removido!"}), 200
        return jsonify({"erro": "Senha incorreta"}), 403
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

if __name__ == '__main__':
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)
    print("SERVIÇO DA GARAGEM LIGADO NA PORTA 5000!")
    app.run(debug=True)