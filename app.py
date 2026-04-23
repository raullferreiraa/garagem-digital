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
    conexao = mysql.connector.connect(**db_config)
    cursor = conexao.cursor(dictionary=True)
    cursor.execute("SELECT id, nome_dono, modelo, ano, cor, placa, tipo_suspensao, aro_roda, foto_url FROM carros")
    meus_carros = cursor.fetchall()
    cursor.close()
    conexao.close()
    return jsonify(meus_carros)

@app.route('/carros', methods=['POST'])
def cadastrar_carro():
    dados = request.form
    foto = request.files.get('foto')
    
    nome_foto = ""
    if foto:
        nome_foto = secure_filename(foto.filename)
        foto.save(os.path.join(app.config['UPLOAD_FOLDER'], nome_foto))

    try:
        conexao = mysql.connector.connect(**db_config)
        cursor = conexao.cursor()
        sql = """INSERT INTO carros (nome_dono, modelo, ano, cor, placa, tipo_suspensao, aro_roda, foto_url, senha_edicao) 
                 VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)"""
        
        valores = (dados['nome_dono'], dados['modelo'], dados['ano'], dados['cor'], dados['placa'],
                   dados['tipo_suspensao'], dados['aro_roda'], nome_foto, dados['senha_edicao'])
        cursor.execute(sql, valores)
        conexao.commit()
        return jsonify({"mensagem": "Projeto salvo!"}), 201
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/carros/<int:id>', methods=['DELETE'])
def excluir_carro(id):
    senha_cliente = request.json.get('senha')
    
    conexao = mysql.connector.connect(**db_config)
    cursor = conexao.cursor(dictionary=True)
    
    cursor.execute("SELECT senha_edicao FROM carros WHERE id = %s", (id,))
    carro = cursor.fetchone()
    
    if carro and carro['senha_edicao'] == senha_cliente:
        cursor.execute("DELETE FROM carros WHERE id = %s", (id,))
        conexao.commit()
        return jsonify({"mensagem": "Removido!"}), 200
    else:
        return jsonify({"erro": "Senha incorreta ou dono não autorizado"}), 403

if __name__ == '__main__':
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)
    app.run(debug=True)