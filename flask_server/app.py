from flask import Flask, request, jsonify
from google import genai
from google.genai import types
import os
import json
import textwrap

# --- Flask App Initialization ---
app = Flask(__name__)

# --- Default Language ---
user_language = "English"

# --- Build System Prompt ---
def build_system_prompt(language):
    return textwrap.dedent(f"""
    You are a friendly, concise, and professional AI assistant.

    Your only job is to help the user in their chosen topic like Health, Education, or Technology.
    You must always reply in **{language} language only**.

    --- RULES ---
    1. Use natural and fluent {language}.
    2. Keep responses short and to the point.
    3. Do not mix other languages.
    4. If user says reset/cancel, end conversation politely in {language}.
    5. When giving choices, include them in this exact format:
       <<OPTION:Option 1>>
       <<OPTION:Option 2>>
       <<OPTION:Option 3>>

    Example:
    User: Tell me about health check-ups
    Assistant:
    Sure! To help you best, are you interested in:
    <<OPTION:General Information>>
    <<OPTION:Types of Check-ups>>
    <<OPTION:What to Expect>>
    """)

WELCOME_MESSAGE_TEXT = "Hello! I’m your Personal AI Assistant. How can I help you today?"

# --- Initialize Gemini ---
try:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable not found.")
    client = genai.Client(api_key=api_key)
    print("✅ Gemini client initialized successfully.")
except Exception as e:
    print(f"❌ Gemini initialization error: {e}")
    client = None

# --- Global conversation history ---
conversation_history = []


# --- Reset conversation ---
def reset_conversation(language):
    global conversation_history
    conversation_history = [
        types.Content(role="user", parts=[types.Part(text=build_system_prompt(language))]),
        types.Content(role="model", parts=[types.Part(text=WELCOME_MESSAGE_TEXT)])
    ]


reset_conversation(user_language)


# --- Helper: Translate text into target language ---
def translate_text(text, target_language):
    if client is None:
        return text
    try:
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=[f"Translate this into {target_language}: {text}"],
            config=types.GenerateContentConfig(temperature=0.3)
        )
        return response.text.strip()
    except Exception as e:
        print(f"⚠️ Translation error: {e}")
        return text


# --- Get Gemini response with enforced language ---
def get_gemini_response(history, user_input):
    global client, user_language
    if client is None:
        return "🤖 Error: Gemini client not initialized."

    try:
        # Always rebuild prompt before each message to force language
        system_prompt = build_system_prompt(user_language)

        # Add reminder to include option format
        user_input = user_input + "\nRemember: Include any choices in <<OPTION:...>> format if relevant."

        contents = [
            types.Content(role="user", parts=[types.Part(text=system_prompt)]),
            *history,
            types.Content(role="user", parts=[types.Part(text=user_input)])
        ]

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents,
            config=types.GenerateContentConfig(temperature=0.5)
        )

        response_content = response.candidates[0].content
        history.append(response_content)
        return response.text.strip()
    except Exception as e:
        print(f"❌ Gemini API error: {e}")
        return "🤖 Error: Could not contact Gemini model."


# --- Flask endpoint for chatbot ---
@app.route('/chatbot', methods=['POST'])
def get_chat_response():
    global conversation_history, user_language

    data = request.get_json()
    user_input = data.get('user_input', '').strip()
    selected_language = data.get('language', user_language)
    user_input_lower = user_input.lower()

    # --- Language switch ---
    if selected_language != user_language:
        print(f"🌐 Language switched: {user_language} → {selected_language}")
        user_language = selected_language

        reset_conversation(user_language)
        return jsonify({
            'response': f"✅ भाषा {user_language} में बदल दी गई है। अब मैं {user_language} में बात करूंगा!",
            'language': user_language
        })

    # --- Reset command ---
    if any(k in user_input_lower for k in ["reset", "cancel", "stop", "start over"]):
        reset_conversation(user_language)
        return jsonify({'response': f"🔄 Conversation reset. Continuing in {user_language}."})

    # --- Normal chat response ---
    bot_response = get_gemini_response(conversation_history, user_input)
    return jsonify({'response': bot_response, 'language': user_language})


# --- Run Flask app ---
if __name__ == '__main__':
    print("🤖 Personal AI Chatbot Server starting...")
    if client is None:
        print("⚠️ WARNING: Gemini API key missing. Please set GEMINI_API_KEY before running.")
    app.run(host='0.0.0.0', port=5000, debug=True)
