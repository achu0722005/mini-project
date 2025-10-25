import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart' as launcher; // <--- ADDED PREFIX 'as launcher'

// Data model for a single chat message
class Message {
  final String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}

// --- ChatGPT Color Theme ---
const Color background = Color(0xFF343541); // Main background
const Color appBarColor = Color(0xFF202123); // Darker top bar
const Color botBubbleColor = Color(0xFF444654); // Bot message bubble
const Color userBubbleColor = Color(0xFF0D9276); // User message bubble (greenish)
const Color sendButtonColor = Color(0xFF10A37F); // ChatGPT green
const Color inputFieldColor = Color(0xFF40414F); // Input bar color
const Color hintTextColor = Color(0xFF8E8EA0); // Subtle hint text
const Color botTextColor = Color(0xFFE1E1E6); // Soft off-white bot text
const Color userTextColor = Colors.white;

void main() {
  runApp(const ChatbotApp());
}

class ChatbotApp extends StatelessWidget {
  const ChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Assistant Bot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: sendButtonColor),
        useMaterial3: true,
      ),
      home: const ChatContainer(),
    );
  }
}

// --- NEW ROOT WIDGET TO MANAGE CHAT VISIBILITY ---
class ChatContainer extends StatefulWidget {
  const ChatContainer({super.key});

  @override
  State<ChatContainer> createState() => _ChatContainerState();
}

class _ChatContainerState extends State<ChatContainer> {
  // Static key to preserve the state of the ChatScreen when it is hidden/shown
  final GlobalKey<_ChatScreenState> _chatScreenKey = GlobalKey<_ChatScreenState>();
  bool _isChatOpen = false; // Start with the chat CLOSED in the Container state

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure Navigator operations happen after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openChatWithAnimation();
    });
  }

  // Custom route that includes the scale animation
  Route _createPopupRoute() {
    return PageRouteBuilder(
      // Prevents the animation from interfering with background content
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(key: _chatScreenKey),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Define the bouncy scale animation
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.elasticOut; // Provides the 'pop' and 'bounce' effect

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return ScaleTransition(
          scale: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  void _openChatWithAnimation() {
    // When opening the chat, we push the animated route
    Navigator.of(context).push(_createPopupRoute()).then((_) {
      // This runs when the ChatScreen is popped (minimized)
      setState(() {
        _isChatOpen = false; // Set to false when chat screen is popped/minimized
      });
      _chatScreenKey.currentState?._inactivityTimer?.cancel();
    });
    // Update the state here to reflect that the chat is now open in the navigator
    setState(() {
      _isChatOpen = true;
    });
    // Start the timer immediately upon opening
    _chatScreenKey.currentState?._startInactivityTimer();
  }

  void _minimizeChat() {
    // We only minimize if the chat is currently open (in the navigator stack)
    if (_isChatOpen) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The build function now only handles the initial state (empty screen)
    // and the minimized state (floating FAB). The full ChatScreen is managed
    // by the Navigator, which is automatically triggered in initState.

    // Check if the chat is NOT open, or if it's the very first frame where it's
    // starting up. We show the FAB ONLY when minimized.
    if (!_isChatOpen) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          // --- REPLACED Icon with Image.network ---
          child: Image.network(
            'http://googleusercontent.com/image_generation_content/0',
            width: 150,
            height: 150,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.psychology_alt,
              size: 150,
              color: hintTextColor.withOpacity(0.2),
            ),
          ),
          // --- END REPLACEMENT ---
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openChatWithAnimation, // Use the new animation function
          backgroundColor: sendButtonColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniStartFloat,
      );
    }

    // When _isChatOpen is true, we return an empty Scaffold to act as the base
    // for the animated ChatScreen to pop up over.
    return WillPopScope(
      onWillPop: () async {
        _minimizeChat();
        return false; // Prevent default app exit
      },
      child: Scaffold(
        backgroundColor: background,
        body: Center(
          child: Container(),
        ),
      ),
    );
  }
}
// --- END NEW ROOT WIDGET ---

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [
    Message(
      text: "Hello! I am your personal assistant. How can I help you today?",
      isUser: false,
    ),
  ];

  bool _isLoading = false;
  Timer? _inactivityTimer;
  static const int _inactivityDurationSeconds = 180; // Increased to 3 minutes
  static const String _baseUrl = 'http://10.0.2.2:5000/chatbot';

  @override
  void initState() {
    super.initState();
    // No need to call _startInactivityTimer here; it's managed by ChatContainer
    _scrollController.addListener(_resetInactivityTimer);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Inactivity Timer Logic ---

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
        const Duration(seconds: _inactivityDurationSeconds), _handleInactivity);
  }

  void _resetInactivityTimer() {
    if (_scrollController.hasClients) {
      _startInactivityTimer();
    }
  }

  void _handleInactivity() {
    _sendResetCommand();
  }

  Future<void> _sendResetCommand() async {
    if (_messages.length <= 1) return;

    setState(() {
      _messages.add(
        Message(
          text: "System: Inactivity detected. Resetting conversation state...",
          isUser: false,
        ),
      );
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_input': 'auto_reset_scroll'}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages.add(Message(text: data['response'] ?? "Error: Empty response from server.", isUser: false));
          _isLoading = false;
        });
      }
    } on TimeoutException {
      // Handle timeout gracefully during auto-reset
      setState(() {
        _messages.add(
          Message(
            text: "Error: Auto-reset timed out. Is the Python Flask server running?",
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          Message(
            text: "Error during auto-reset. ($e)",
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    } finally {
      _scrollToBottom();
      _startInactivityTimer();
    }
  }

  // --- NEW: Function to launch the native Share Sheet (Mail/SMS) ---
  Future<void> _shareLatestBotResponse() async {
    final botMessages = _messages.where((m) => !m.isUser).toList();
    if (botMessages.isEmpty) {
      // No bot message to share
      return;
    }

    final String content = botMessages.last.text;

    // 1. Clean up the content (remove tags and formatting)
    final RegExp tagRegex = RegExp(r'<<OPTION:[^>]+>>');
    String shareContent = content.replaceAll(tagRegex, '').trim();
    shareContent = shareContent.replaceAll(RegExp(r'\s*\[([^\]]+)\]'), '').trim();
    shareContent = shareContent.replaceAll('---', '\n---\n');
    shareContent = shareContent.replaceAll('\n\n', '\n');

    const String subject = 'Advice from my Personal Assistant Bot';
    final String body = 'My Personal Assistant Bot gave me this advice:\n\n$shareContent';

    // 2. Construct the mailto URI. This is the most reliable way to trigger
    // the system's share dialogue on many devices, as it often opens the email
    // app or presents a choice of handlers.
    final Uri uri = Uri(
      scheme: 'mailto',
      path: '', // No specific email address, making it a general share intent
      queryParameters: {
        'subject': Uri.encodeComponent(subject), // Ensure subject is URL-safe
        'body': Uri.encodeComponent(body),       // Ensure body is URL-safe
      },
    );

    // 3. Launch the URI
    try {
      if (await launcher.canLaunchUrl(uri)) {
        await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
      } else {
        // Fallback for systems that don't recognize mailto as a share intent (e.g., desktop)
        print('Could not launch mailto URI. URI: $uri');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _isLoading) return;
    _resetInactivityTimer();

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_input': text}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages.add(Message(text: data['response'] ?? "Error: Empty response from server.", isUser: false));
          _isLoading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _messages.add(
          Message(
            text: "Error: Connection timed out. Is the Python Flask server running?",
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          Message(
            text:
            "Error: Could not connect to the Python server. Ensure it is running on port 5000. ($e)",
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    } finally {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  final List<String> _topicSuggestions = [
    'Health Check-up',
    'Goal Setting',
    'Investing Tips',
    'Fitness Goals',
    'Schedule A Reminder',
    'Generate Idea',
    'Quick Riddle',
    'Define NLP',
  ];

  Widget _buildTopicChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _topicSuggestions.map((topic) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                label: Text(topic,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                backgroundColor: sendButtonColor,
                elevation: 2,
                onPressed: () => _sendMessage(topic),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputComposer() {
    return Container(
      decoration: const BoxDecoration(color: appBarColor),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _sendMessage,
                style: const TextStyle(color: userTextColor),
                decoration: InputDecoration(
                  hintText: 'Send a message...',
                  hintStyle: const TextStyle(color: hintTextColor),
                  filled: true,
                  fillColor: inputFieldColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: sendButtonColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed:
                _isLoading ? null : () => _sendMessage(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the dynamic, tappable chips that appear *below* the bot's message
  Widget _buildOptionChips(String text) {
    // Regex to find all <<OPTION:Choice>> patterns
    final RegExp regex = RegExp(r'<<OPTION:([^>]+)>>');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) return const SizedBox.shrink(); // Hide if no options found

    final List<String> options = matches.map((m) => m.group(1)!).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Wrap(
        spacing: 8.0, // horizontal gap
        runSpacing: 4.0, // vertical gap
        children: options.map((option) {
          return ActionChip(
            label: Text(option, style: const TextStyle(color: sendButtonColor, fontWeight: FontWeight.w500)),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: sendButtonColor, width: 1.5),
            ),
            onPressed: () => _sendMessage(option),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    // 1. Check for options and strip them from the message text
    final RegExp regex = RegExp(r'<<OPTION:[^>]+>>');
    String cleanText = message.text.replaceAll(regex, '').trim();

    // 2. Remove the old, bracketed text (leftover from previous Python versions)
    cleanText = cleanText.replaceAll(RegExp(r'\s*\[([^\]]+)\]'), '').trim();

    // 3. Determine alignment and color
    final alignment =
    message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser ? userBubbleColor : botBubbleColor;
    final textColor = message.isUser ? userTextColor : botTextColor;

    // 4. Extract options for dynamic chips below the text
    final optionChips = _buildOptionChips(message.text);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
        child: Column(
          crossAxisAlignment:
          message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: message.isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(12.0),
              child: Text(
                cleanText,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            ),
            // Renders the dynamic option chips below the bot message
            if (!message.isUser) optionChips,
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: appBarColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: sendButtonColor),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- REPLACED Icon with Image.network in Drawer ---
                Image.network(
                  'http://googleusercontent.com/image_generation_content/0',
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.psychology_alt,
                        color: sendButtonColor, size: 30),
                  ),
                ),
                // --- END REPLACEMENT ---
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AI Assistant',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'v1.0.0 (Rule-Based)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title: const Text('Settings', style: TextStyle(color: Colors.white)),
            onTap: () => print('Settings tapped'),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.white),
            title:
            const Text('Conversation History', style: TextStyle(color: Colors.white)),
            onTap: () => print('History tapped'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white),
            title: const Text('About', style: TextStyle(color: Colors.white)),
            onTap: () => print('About tapped'),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 20.0),
            child: Text(
              'Developed by Akshay',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scrollToBottom();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Assistant Bot'),
        // --- ADDED Share Button to AppBar ---
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLatestBotResponse,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => print('Search tapped'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => print('Profile tapped'),
          ),
          const SizedBox(width: 8),
        ],
        // --- END ADDED Share Button ---
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildTopicChips(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              color: sendButtonColor,
              backgroundColor: Colors.transparent,
              minHeight: 3,
            ),
          _buildInputComposer(),
        ],
      ),
    );
  }
}
