from flask import Flask, request, jsonify
import re # Used for advanced pattern matching
import random # Import the random module to pick a riddle

app = Flask(__name__)

# --- GLOBAL CONVERSATION STATE MANAGEMENT ---
# This dictionary holds the ongoing context for each user (though in this single-user
# implementation, we use a single global state).
# Keys: 'topic', 'phase', 'data'
conversation_state = {
    'topic': None,
    'phase': 0,
    'data': {}
}

# --- RIDDLE DATABASE ---
# List of riddles, each stored as a tuple (riddle_text, answer, hint)
RIDDLES = [
    (
        "I am always wet, but never rain. I am what you use when you want to be clean again. What am I?",
        "A towel",
        "Think about what you use in the bathroom after a shower."
    ),
    (
        "What has an eye but cannot see?",
        "A needle",
        "You use me to fix things you wear."
    ),
    (
        "What is full of holes but still holds water?",
        "A sponge",
        "I live by the sink or in the tub."
    ),
    (
        "What question can you never answer yes to?",
        "Are you asleep yet?",
        "The act of answering proves the opposite of the question."
    )
]

# --- UTILITY FUNCTION ---

def get_fallback_response(user_input):
    """Returns a general response and resets the state."""
    global conversation_state
    
    # Check if the user is in the middle of a flow but says something like 'cancel'
    if conversation_state['topic'] is not None and user_input.lower() in ['cancel', 'stop', 'quit', 'reset']:
        conversation_state = {'topic': None, 'phase': 0, 'data': {}}
        return "Conversation cancelled. How else can I assist you? Select a topic above to start."

    conversation_state = {'topic': None, 'phase': 0, 'data': {}}
    return "I'm sorry, I don't have a specific flow for that yet. Try selecting one of the main topics above to start a deeper conversation."

def reset_state(user_input):
    """
    Resets the state after a conversation flow is complete.
    Checks user input for final negative/closing keywords to provide a natural closing.
    """
    global conversation_state

    user_input_lower = user_input.lower()

    # Define common closing phrases
    closing_keywords = ['no', 'nope', 'none', 'nothing', 'thats all', 'that is all', 'bye', 'thanks', 'thank you']

    # Check if the last input suggests the user is done with the current interaction
    if any(keyword in user_input_lower for keyword in closing_keywords):
        message = "Understood! Thank you for chatting. Feel free to select a new topic whenever you're ready."
    else:
        # --- ENHANCED CLOSING MESSAGE ---
        topic = conversation_state.get('topic')
        if topic == 'health':
            message = "Great work checking in on your well-being! Remember to prioritize **consistency over perfection** this week."
        elif topic == 'goal_setting':
            message = "Goal set! Now that your **S.M.A.R.T. goal** is defined, you're already one step closer to achieving it. Go crush it!"
        elif topic == 'reminder':
            message = "Reminder confirmed! Your assistant has the details locked in. Don't worry about forgetting—you're covered."
        elif topic == 'idea':
            message = "Brainstorming is complete! That's a solid foundation for your idea. Time to turn inspiration into action!"
        else:
            message = "Flow complete. Ready for a new topic? Select one of the chips above."
        # --- END ENHANCED CLOSING MESSAGE ---

    # Perform the actual reset
    conversation_state = {'topic': None, 'phase': 0, 'data': {}}
    return message

# --- TOPIC HANDLERS ---

# --------------------------
# 1. HEALTH FLOW (Sleep, Water, Stress, Movement, Diet)
# --------------------------

def handle_health_flow(user_input):
    global conversation_state
    user_input_lower = user_input.lower()
    data = conversation_state['data']

    # Phase 1: Initial Prompt (Triggered by 'Health Check-up' chip)
    if conversation_state['phase'] == 1:
        data.update({'sleep': None, 'water': None, 'stress': None, 'movement': None, 'diet': None}) 
        conversation_state['phase'] = 2
        return "Let's check in on your well-being. On average, how many hours of **sleep** did you get last night? <<OPTION:Less than 6h>><<OPTION:6-8 hours>><<OPTION:8+ hours>>"

    # Phase 2: Get Sleep
    elif conversation_state['phase'] == 2:
        if 'less' in user_input_lower:
            data['sleep'] = 'Less than 6h'
        elif '6-8' in user_input_lower:
            data['sleep'] = '6-8 hours'
        elif '8+' in user_input_lower:
            data['sleep'] = '8+ hours'
        else:
            return "Please select a range for sleep: <<OPTION:Less than 6h>><<OPTION:6-8 hours>><<OPTION:8+ hours>>"
        
        conversation_state['phase'] = 3
        return f"Sleep noted as **{data['sleep']}**. How many glasses of **water** (approx. 250ml) did you drink today? <<OPTION:0-3 Glasses>><<OPTION:4-7 Glasses>><<OPTION:8+ Glasses>>"

    # Phase 3: Get Water Intake
    elif conversation_state['phase'] == 3:
        if '0-3' in user_input_lower:
            data['water'] = '0-3 Glasses'
        elif '4-7' in user_input_lower:
            data['water'] = '4-7 Glasses'
        elif '8+' in user_input_lower:
            data['water'] = '8+ Glasses'
        else:
            return "Please choose a water intake range: <<OPTION:0-3 Glasses>><<OPTION:4-7 Glasses>><<OPTION:8+ Glasses>>"

        conversation_state['phase'] = 4
        return f"Water intake confirmed as **{data['water']}**. How would you rate your current **stress level**? <<OPTION:Low>><<OPTION:Moderate>><<OPTION:High>>"

    # Phase 4: Get Stress Level
    elif conversation_state['phase'] == 4:
        if 'low' in user_input_lower:
            data['stress'] = 'Low'
        elif 'moderate' in user_input_lower:
            data['stress'] = 'Moderate'
        elif 'high' in user_input_lower:
            data['stress'] = 'High'
        else:
            return "Please rate your stress level: <<OPTION:Low>><<OPTION:Moderate>><<OPTION:High>>"

        conversation_state['phase'] = 5
        return f"Stress level set to **{data['stress']}**. On average, how many days a week do you get **30 minutes of intentional movement/exercise**? <<OPTION:0-1 Day>><<OPTION:2-4 Days>><<OPTION:5+ Days>>"
    
    # Phase 5: Get Movement/Exercise
    elif conversation_state['phase'] == 5:
        if '0-1' in user_input_lower:
            data['movement'] = '0-1 Day'
        elif '2-4' in user_input_lower:
            data['movement'] = '2-4 Days'
        elif '5+' in user_input_lower:
            data['movement'] = '5+ Days'
        else:
            return "Please select your weekly movement: <<OPTION:0-1 Day>><<OPTION:2-4 Days>><<OPTION:5+ Days>>"
        
        conversation_state['phase'] = 6
        return f"Movement noted: **{data['movement']}**. Last question: How often do you feel you make **nutritious food choices**? <<OPTION:Most of the Time>><<OPTION:Sometimes>><<OPTION:Rarely>>"

    # Phase 6: Get Diet/Nutrition and Finalize
    elif conversation_state['phase'] == 6:
        if 'most' in user_input_lower:
            data['diet'] = 'Most of the Time'
        elif 'sometimes' in user_input_lower:
            data['diet'] = 'Sometimes'
        elif 'rarely' in user_input_lower:
            data['diet'] = 'Rarely'
        else:
            return "Please select a nutrition rating: <<OPTION:Most of the Time>><<OPTION:Sometimes>><<OPTION:Rarely>>"

        # Generate advice based on gathered data
        advice = ""
        issues = []
        if data['sleep'].startswith('Less'): issues.append('Sleep')
        if data['water'].startswith('0-3'): issues.append('Hydration')
        if data['stress'] == 'High': issues.append('Stress')
        if data['movement'].startswith('0-1'): issues.append('Movement')
        if data['diet'] == 'Rarely': issues.append('Diet')

        if not issues:
            advice = "Overall, your habits are excellent! Maintain this balance and consistency."
        elif len(issues) == 1:
            advice = f"Focus on this key area: **{issues[0]}**. A small, consistent change here will have a big impact."
        else:
            advice = f"You have a few opportunities for improvement ({', '.join(issues)}). Start by targeting **{issues[0]}** first for the easiest win."


        summary = (
            "--- Comprehensive Health Summary ---\n"
            f"Sleep: {data['sleep']}\n"
            f"Water: {data['water']}\n"
            f"Stress: {data['stress']}\n"
            f"Movement: {data['movement']}\n"
            f"Diet: {data['diet']}\n"
            "------------------------------------\n"
        )
        response = f"Health Check-up Complete!\n\n{summary}\n**My Recommendation:** {advice}"
        return response + "\n\n" + reset_state(user_input)

    return get_fallback_response(user_input)
    
# --------------------------
# 2. GOAL SETTING FLOW (S.M.A.R.T.)
# --------------------------

def handle_goal_setting_flow(user_input):
    global conversation_state
    user_input_lower = user_input.lower()
    data = conversation_state['data']

    # Phase 1: Initial Prompt (Triggered by 'Goal Setting' chip)
    if conversation_state['phase'] == 1:
        data.update({'subject': None, 'metric': None, 'deadline': None}) 
        conversation_state['phase'] = 2
        return "Let's set a **S.M.A.R.T. Goal**. What is the specific **subject** of your goal (e.g., 'Learn Python', 'Finish Project')?"

    # Phase 2: Get Subject
    elif conversation_state['phase'] == 2:
        if len(user_input) < 5:
            return "Please enter a subject longer than a few characters."
        data['subject'] = user_input
        conversation_state['phase'] = 3
        return f"Subject set: **{data['subject']}**. How will you **measure** this goal? <<OPTION:Completion (Yes/No)>><<OPTION:Quantity (Number)>><<OPTION:Time (Hours)>>"

    # Phase 3: Get Metric
    elif conversation_state['phase'] == 3:
        if 'completion' in user_input_lower:
            data['metric'] = 'Completion (Binary)'
        elif 'quantity' in user_input_lower:
            data['metric'] = 'Quantity (Number)'
        elif 'time' in user_input_lower:
            data['metric'] = 'Time (Hours Spent)'
        else:
            return "Please select a measurement method: <<OPTION:Completion (Yes/No)>><<OPTION:Quantity (Number)>><<OPTION:Time (Hours)>>"
        
        conversation_state['phase'] = 4
        return f"Metric set as **{data['metric']}**. What is the **deadline** or time-bound element?"

    # Phase 4: Get Deadline and Finalize
    elif conversation_state['phase'] == 4:
        if len(user_input) < 3:
            return "Please enter a deadline (e.g., 'Next Friday' or 'End of Semester')."
        data['deadline'] = user_input

        summary = (
            "--- S.M.A.R.T. Goal Summary ---\n"
            f"Subject (Specific): {data['subject']}\n"
            f"Metric (Measurable): {data['metric']}\n"
            f"Deadline (Time-bound): {data['deadline']}\n"
            "------------------------------\n"
        )
        response = f"Goal Created! Your assistant will track:\n\n{summary}"
        return response + "\n\n" + reset_state(user_input)

    return get_fallback_response(user_input)

# --------------------------
# 3. INVESTING FLOW (Risk, Goal, Horizon)
# --------------------------

def handle_investing_flow(user_input):
    global conversation_state
    response = ""
    user_input_lower = user_input.lower()
    data = conversation_state['data']

    # Phase 1: Initial Prompt (Triggered by 'Investing Tips' chip)
    if conversation_state['phase'] == 1:
        # Initialize data for the flow to avoid KeyError later
        data.update({'risk': None, 'goal': None, 'horizon': None}) 
        
        conversation_state['phase'] = 2
        return "As your financial assistant, I recommend starting with a **low-cost ETF** for diversification. What is your **risk tolerance**? <<OPTION:Low>><<OPTION:Medium>><<OPTION:High>>"

    # Phase 2: Get Risk Tolerance
    elif conversation_state['phase'] == 2:
        if 'low' in user_input_lower:
            data['risk'] = 'Low'
        elif 'medium' in user_input_lower:
            data['risk'] = 'Medium'
        elif 'high' in user_input_lower:
            data['risk'] = 'High'
        else:
            return "Please select a valid risk level: <<OPTION:Low>><<OPTION:Medium>><<OPTION:High>>"
        
        conversation_state['phase'] = 3
        return f"Understood, your risk tolerance is **{data['risk']}**. What is your main **Investment Goal**? <<OPTION:Retirement Planning>><<OPTION:Passive Income>><<OPTION:Car Purchase>>"

    # Phase 3: Get Investment Goal
    elif conversation_state['phase'] == 3:
        # NOTE: If the user types the full button text (e.g., 'Retirement Planning'), this logic handles it.
        if 'retirement' in user_input_lower:
            data['goal'] = 'Retirement Planning'
        elif 'passive' in user_input_lower:
            data['goal'] = 'Passive Income'
        elif 'car' in user_input_lower:
            data['goal'] = 'Car Purchase'
        else:
            return "Please specify your goal: <<OPTION:Retirement Planning>><<OPTION:Passive Income>><<OPTION:Car Purchase>>"

        conversation_state['phase'] = 4
        return f"Goal set for **{data['goal']}**. What is your **Investment Horizon** (how long until you need the money)? <<OPTION:Short Term (0-3 yrs)>><<OPTION:Medium Term (4-10 yrs)>><<OPTION:Long Term (10+ yrs)>>"
    
    # Phase 4: Get Investment Horizon (Fixed to accept full button labels)
    elif conversation_state['phase'] == 4:
        horizon = None
        
        # Check for full button label matches (most reliable for buttons)
        if 'short term (0-3 yrs)' in user_input_lower:
            horizon = 'Short Term (0-3 yrs)'
        elif 'medium term (4-10 yrs)' in user_input_lower:
            horizon = 'Medium Term (4-10 yrs)'
        elif 'long term (10+ yrs)' in user_input_lower:
            horizon = 'Long Term (10+ yrs)'
        
        # Fallback check for keywords and ranges (for manual user input)
        elif any(term in user_input_lower for term in ['short', '0-3']):
            horizon = 'Short Term (0-3 yrs)'
        elif any(term in user_input_lower for term in ['medium', '4-10', '5-10']):
            horizon = 'Medium Term (4-10 yrs)'
        elif any(term in user_input_lower for term in ['long', '10+', '20']):
            horizon = 'Long Term (10+ yrs)'
        
        if horizon:
            data['horizon'] = horizon
            conversation_state['phase'] = 5 # Move to summary/advice
        else:
            return "Please specify your horizon. Try selecting one of the options below."

    # Phase 5: Final Summary and Advice
    elif conversation_state['phase'] == 5:
        # Generate personalized advice based on gathered data
        advice = ""
        if data['risk'] == 'Low' and data['horizon'].startswith('Short'):
            advice = "Recommendation: Focus on **high-yield savings** and **short-term bonds** to preserve capital."
        elif data['risk'] == 'Medium' and data['horizon'].startswith('Medium'):
            advice = "Recommendation: A balanced portfolio of **60% ETFs (Stocks)** and **40% Bonds/Cash** is suitable for steady growth."
        elif data['risk'] == 'High' and data['horizon'].startswith('Long'):
            advice = "Recommendation: You can afford to be aggressive. A portfolio of **90%+ broad market equity ETFs** is recommended for maximizing long-term gains."
        else:
             advice = "Recommendation: Given your specific risk and horizon, a diversified **Target Date Fund (TDF)** might be the simplest, most effective solution for hands-off management."

        summary = (
            "--- Investment Summary ---\n"
            f"Risk Tolerance: {data['risk']}\n"
            f"Goal: {data['goal']}\n"
            f"Horizon: {data['horizon']}\n"
            "--------------------------\n"
        )
        response = f"Thank you! Here is your plan:\n\n{summary}\n{advice}"
        return response + "\n\n" + reset_state(user_input)
    
    return get_fallback_response(user_input)

# --------------------------
# 4. FITNESS FLOW (Goal, Frequency, Activity)
# --------------------------

def handle_fitness_flow(user_input):
    global conversation_state
    response = ""
    user_input_lower = user_input.lower()
    data = conversation_state['data']

    # Phase 1: Initial Prompt (Triggered by 'Fitness Goals' chip)
    if conversation_state['phase'] == 1:
        data.update({'goal': None, 'frequency': None, 'activity': None}) 
        conversation_state['phase'] = 2
        return "Let's build a plan. What is your primary **fitness goal**? <<OPTION:Weight Loss>><<OPTION:Build Muscle>><<OPTION:Increase Endurance>>"

    # Phase 2: Get Goal
    elif conversation_state['phase'] == 2:
        if 'loss' in user_input_lower:
            data['goal'] = 'Weight Loss'
        elif 'muscle' in user_input_lower:
            data['goal'] = 'Muscle Gain'
        elif 'endurance' in user_input_lower:
            data['goal'] = 'Endurance Training'
        else:
            return "Please choose one of the main goals: <<OPTION:Weight Loss>><<OPTION:Build Muscle>><<OPTION:Increase Endurance>>"

        conversation_state['phase'] = 3
        return f"Great, **{data['goal']}** is the focus. How many times per week do you plan to **exercise**? <<OPTION:1-2 Days>><<OPTION:3-4 Days>><<OPTION:5+ Days>>"

    # Phase 3: Get Frequency
    elif conversation_state['phase'] == 3:
        if '1-2 days' in user_input_lower or '3-4 days' in user_input_lower or '5+ days' in user_input_lower:
            data['frequency'] = user_input
        else:
            return "Please select a frequency: <<OPTION:1-2 Days>><<OPTION:3-4 Days>><<OPTION:5+ Days>>"

        conversation_state['phase'] = 4
        return f"Finally, what is your **preferred activity**? <<OPTION:Strength Training>><<OPTION:Cardio Focus>><<OPTION:Hybrid>>"

    # Phase 4: Get Activity and Give Advice
    elif conversation_state['phase'] == 4:
        if 'strength training' in user_input_lower:
            data['activity'] = 'Strength Training'
        elif 'cardio focus' in user_input_lower:
            data['activity'] = 'Cardio Focus'
        elif 'hybrid' in user_input_lower:
            data['activity'] = 'Hybrid (Mix)'
        else:
            return "Please select an activity type: <<OPTION:Strength Training>><<OPTION:Cardio Focus>><<OPTION:Hybrid>>"
        
        # Generate advice
        advice = ""
        if data['goal'] == 'Weight Loss' and data['activity'] == 'Cardio Focus':
            advice = "Recommendation: Focus on **High-Intensity Interval Training (HIIT)** on your training days, combined with a caloric deficit."
        elif data['goal'] == 'Muscle Gain' and data['activity'] == 'Strength Training':
            advice = "Recommendation: Implement a **Progressive Overload** routine, focusing on compound lifts (squats, bench press) 3-4 times per week."
        elif data['goal'] == 'Endurance Training':
            advice = "Recommendation: Follow the **80/20 rule** (80% easy effort, 20% high intensity) to build your aerobic base effectively."
        else:
            advice = "Recommendation: Consistent effort is key. Ensure your diet supports your goal and prioritize sleep."
            
        summary = (
            f"Goal: {data['goal']}\n"
            f"Frequency: {data['frequency']}\n"
            f"Activity: {data['activity']}\n"
        )
        response = f"Plan Confirmed:\n\n{summary}\n{advice}"
        return response + "\n\n" + reset_state(user_input)

    return get_fallback_response(user_input)

# --------------------------
# 5. IDEA GENERATION FLOW (Topic, Audience, Format)
# --------------------------

def handle_idea_flow(user_input):
    global conversation_state
    user_input_lower = user_input.lower()
    data = conversation_state['data']

    # Phase 1: Initial Prompt (Triggered by 'Generate Idea' chip)
    if conversation_state['phase'] == 1:
        data.update({'topic': None, 'audience': None, 'format': None})
        conversation_state['phase'] = 2
        return "I can help you brainstorm! What is the **general topic** you need an idea for?"

    # Phase 2: Get Topic
    elif conversation_state['phase'] == 2:
        data['topic'] = user_input
        conversation_state['phase'] = 3
        return f"Topic: **{data['topic']}**. Who is the **target audience**? <<OPTION:Students>><<OPTION:Professionals>><<OPTION:General Public>>"

    # Phase 3: Get Audience
    elif conversation_state['phase'] == 3:
        if 'student' in user_input_lower:
            data['audience'] = 'Students'
        elif 'professional' in user_input_lower:
            data['audience'] = 'Professionals'
        elif 'general' in user_input_lower:
            data['audience'] = 'General Public'
        else:
            return "Please select the target audience: <<OPTION:Students>><<OPTION:Professionals>><<OPTION:General Public>>"

        conversation_state['phase'] = 4
        return f"Target: **{data['audience']}**. What **format** should the idea be? <<OPTION:Blog Post>><<OPTION:Video Series>><<OPTION:Mobile App>>"

    # Phase 4: Get Format and Generate Idea
    elif conversation_state['phase'] == 4:
        if 'blog post' in user_input_lower:
            data['format'] = 'Blog Post'
        elif 'video series' in user_input_lower:
            data['format'] = 'Video Series'
        elif 'mobile app' in user_input_lower:
            data['format'] = 'Mobile App'
        else:
            return "Please select a format: <<OPTION:Blog Post>><<OPTION:Video Series>><<OPTION:Mobile App>>"

        # Generate idea based on combination
        idea = f"Idea for a {data['format']} on the topic '{data['topic']}' aimed at {data['audience']}: "
        
        if data['format'] == 'Mobile App' and data['audience'] == 'Students':
            idea += "Develop a **'Study Buddy'** app that uses flashcards and AI-generated practice quizzes related to their coursework."
        elif data['format'] == 'Video Series' and 'investing' in data['topic'].lower():
            idea += "Create a **'3-Minute Money Manager'** video series, breaking down complex financial topics into quick, actionable clips."
        else:
            idea += f"Create a **'Deep Dive'** {data['format']} explaining a controversial or overlooked angle of the '{data['topic']}' topic to {data['audience']}."

        response = f"Brainstorming Complete!\n\n**Idea:** {idea}"
        return response + "\n\n" + reset_state(user_input)

    return get_fallback_response(user_input)

# --------------------------
# 6. REMINDER FLOW (Subject, Time, Priority)
# --------------------------

def handle_reminder_flow(user_input):
    global conversation_state
    user_input_lower = user_input.lower()
    data = conversation_state['data']

    # Phase 1: Initial Prompt (Triggered by 'Schedule A Reminder' chip)
    if conversation_state['phase'] == 1:
        data.update({'subject': None, 'time': None, 'priority': None})
        conversation_state['phase'] = 2
        return "I can schedule that. What is the **subject** of the reminder (e.g., 'Pay the electricity bill')?"

    # Phase 2: Get Subject
    elif conversation_state['phase'] == 2:
        if len(user_input) < 5:
            return "The subject is too short. Please tell me what to remind you about."
        data['subject'] = user_input
        conversation_state['phase'] = 3
        return f"Got it: **'{data['subject']}'**. What **day and time** should I remind you?"

    # Phase 3: Get Time
    elif conversation_state['phase'] == 3:
        if len(user_input) < 5:
            return "Please provide a time (e.g., 'Tomorrow at 10 AM')."
        data['time'] = user_input
        conversation_state['phase'] = 4
        return f"Time set for **{data['time']}**. What **priority level** should this reminder have? <<OPTION:High>><<OPTION:Medium>><<OPTION:Low>>"

    # Phase 4: Get Priority and Finalize
    elif conversation_state['phase'] == 4:
        if 'high' in user_input_lower:
            data['priority'] = 'High'
        elif 'medium' in user_input_lower:
            data['priority'] = 'Medium'
        elif 'low' in user_input_lower:
            data['priority'] = 'Low'
        else:
            return "Please select a priority: <<OPTION:High>><<OPTION:Medium>><<OPTION:Low>>"
        
        # Confirmation message
        response = (
            "Reminder Scheduled!\n"
            f"**Subject:** {data['subject']}\n"
            f"**Time:** {data['time']}\n"
            f"**Priority:** {data['priority']}\n"
        )
        return response + "\n\n" + reset_state(user_input)

    return get_fallback_response(user_input)

# --------------------------
# 7. GENERAL KNOWLEDGE / RIDDLE / NLP
# --------------------------

def handle_knowledge_flow(user_input):
    global conversation_state
    user_input_lower = user_input.lower()
    data = conversation_state['data']
    
    # Check if a sub-flow (Riddle/NLP) is already active
    if conversation_state.get('topic') in ['riddle', 'nlp']:
        
        # Sub-Flow: Riddle 
        if conversation_state['topic'] == 'riddle':
            # Phase 1: Riddle Prompt (Start)
            if conversation_state['phase'] == 1:
                # Select a random riddle from the database
                riddle_data = random.choice(RIDDLES)
                data['riddle_text'] = riddle_data[0]
                data['answer'] = riddle_data[1]
                data['hint'] = riddle_data[2]
                conversation_state['phase'] = 2
                return f"{data['riddle_text']} (Type 'hint' or 'answer' if you give up)"
            
            # Phase 2: Riddle Answer Check/Hint
            elif conversation_state['phase'] == 2:
                # Check if user's input matches the answer (case-insensitive and word-only)
                is_correct = any(word.lower() in user_input_lower for word in data['answer'].split())
                
                if is_correct:
                    response = "That's correct! You got it right."
                elif 'answer' in user_input_lower or 'give up' in user_input_lower:
                    response = f"The answer was **{data['answer']}**. Good try!"
                elif 'hint' in user_input_lower:
                    return f"Hint: {data['hint']} (Try again or type 'answer')"
                else:
                    return "Keep guessing! Type 'hint' for help or 'answer' if you give up."
                
                # If the user answered correctly or gave up, reset the flow.
                return response + "\n\n" + reset_state(user_input)
        
        # Sub-Flow: Define NLP
        elif conversation_state['topic'] == 'nlp':
            # Phase 1: NLP Prompt (Start)
            if conversation_state['phase'] == 1:
                conversation_state['phase'] = 2
                initial_def = "**Natural Language Processing (NLP)** is a branch of AI that gives computers the ability to read, understand, and generate human language."
                return initial_def + "\n\nWould you like to know more about its: <<OPTION:Applications>><<OPTION:History>>"
            
            # Phase 2: NLP Follow-up
            elif conversation_state['phase'] == 2:
                if 'applications' in user_input_lower:
                    advice = "Key NLP applications include translation (Google Translate), sentiment analysis (figuring out if a review is positive or negative), and chatbots like me!"
                elif 'history' in user_input_lower:
                    advice = "NLP began in the 1950s with rule-based systems, but exploded in the 2010s with **Deep Learning** and large language models (LLMs)."
                else:
                    return "Please select: <<OPTION:Applications>><<OPTION:History>>"

                return advice + "\n\n" + reset_state(user_input)

    return get_fallback_response(user_input)


# --- MAIN CHATBOT ENTRY POINT ---

@app.route('/chatbot', methods=['POST'])
def get_chat_response():
    global conversation_state

    # 1. Get the JSON data sent from Flutter
    data = request.get_json()
    user_input = data.get('user_input', '')
    user_input_lower = user_input.lower()

    # Determine the current flow handler based on state
    handler = None
    
    # Check for flow initiation (Phase 0) or ongoing flow
    if conversation_state['phase'] == 0:
        # --- INIT NEW FLOW ---
        if 'health check-up' in user_input_lower: 
            conversation_state.update({'topic': 'health', 'phase': 1, 'data': {}})
        elif 'goal setting' in user_input_lower: 
            conversation_state.update({'topic': 'goal_setting', 'phase': 1, 'data': {}})
        elif 'investing tips' in user_input_lower:
            conversation_state.update({'topic': 'investing', 'phase': 1, 'data': {}})
        elif 'fitness goals' in user_input_lower:
            conversation_state.update({'topic': 'fitness', 'phase': 1, 'data': {}})
        elif 'schedule a reminder' in user_input_lower:
            conversation_state.update({'topic': 'reminder', 'phase': 1, 'data': {}})
        elif 'generate idea' in user_input_lower:
            conversation_state.update({'topic': 'idea', 'phase': 1, 'data': {}})
        elif 'quick riddle' in user_input_lower:
            conversation_state.update({'topic': 'riddle', 'phase': 1, 'data': {}})
        elif 'define nlp' in user_input_lower:
            conversation_state.update({'topic': 'nlp', 'phase': 1, 'data': {}})
        
    # Set handler if a topic is active (either just initiated or ongoing)
    if conversation_state['topic']:
        handler_name = f"handle_{conversation_state['topic']}_flow"
        handler = globals().get(handler_name)
    
    # 2. Check for global state resets
    # --- ADDED CHECK FOR AUTO_RESET_SCROLL ---
    if any(keyword in user_input_lower for keyword in ["reset", "start over", "cancel", "auto_reset_scroll"]):
        message = "Welcome back! Due to inactivity, I've reset the conversation state. Ready when you are!"
        # Perform the actual reset
        conversation_state = {'topic': None, 'phase': 0, 'data': {}}
        return jsonify({'response': message})
    # --- END ADDED CHECK ---

    # 3. Process the request
    if handler:
        try:
            bot_response = handler(user_input)
            return jsonify({'response': bot_response})
        except Exception as e:
            # Log the error for debugging
            print(f"ERROR in active flow handler ({conversation_state['topic']}): {e}")
            bot_response = reset_state("") + "An internal server error occurred. Sorry!"
            return jsonify({'response': bot_response})
    
    # 4. Fallback response for unhandled input (only phase 0 falls here without a topic)
    else:
        # Final check for conversation ending phrases outside a flow
        if any(keyword in user_input_lower for keyword in ['no', 'none', 'bye', 'thanks']):
            return jsonify({'response': reset_state(user_input)})

        return jsonify({'response': get_fallback_response(user_input)})

if __name__ == '__main__':
    # Running on 0.0.0.0 makes it accessible to the Flutter emulator (10.0.2.2)
    # The port 5000 matches the URL in the Flutter code.
    print("Chatbot Server Starting...")
    app.run(host='0.0.0.0', port=5000, debug=True)
