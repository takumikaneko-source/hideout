from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)

# Model
class Message:
    def __init__(self, text):
        self.text = text

messages = []

# Controller & View コメント追加
@app.route('/')
def index():
    return render_template('index.html', messages=messages)

@app.route('/add', methods=['POST'])
def add_message():
    text = request.form['message']
    messages.append(Message(text))
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=True)
