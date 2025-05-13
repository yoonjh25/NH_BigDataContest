# from flask import Flask, request, jsonify, render_template
# from model import search_combined_response # model.py의 함수 import

# app = Flask(__name__)

# @app.route("/")
# def home():
#     return render_template("index.html")  # chat.html 파일이 templates 폴더에 있어야 합니다.

# @app.route("/ask", methods=["POST"])
# def ask():
#     question = request.json.get("question", "")
#     if not question:
#         return jsonify({"error": "No question provided"}), 400
    
#     # 모델의 응답 생성 함수 호출
#     answer = search_combined_response(question)
#     return jsonify({"answer": answer})

# if __name__ == "__main__":
#     app.run(debug=True)

from flask import Flask, request, jsonify, render_template
from mode2l import search_combined_response  # Corrected import

app = Flask(__name__)

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/ask", methods=["POST"])
def ask():
    question = request.json.get("question", "")
    if not question:
        return jsonify({"error": "No question provided"}), 400
    
    # search_combined_response 함수의 결과를 확인하고 응답을 JSON 형식으로 반환
    answer_data = search_combined_response(question)
    response_text = answer_data.get("response", "Sorry, I couldn't find an answer.")  # 기본값 추가
    return jsonify({"answer": response_text})

if __name__ == "__main__":
    app.run(debug=True)




