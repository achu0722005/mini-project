import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> options;

  ChatMessage({required this.text, required this.isUser, this.options = const []});
}

const Color background = Color(0xFF0D1117);
const Color chatBackground = Color(0xFF161B22);
const Color userMessageColor = Color(0xFF1F6FEB);
const Color botMessageColor = Color(0xFF30363D);
const Color hintTextColor = Color(0xFF8B949E);
const Color sendButtonColor = Color(0xFF238636);
const Color lightBackground = Color(0xFFFFFFFF);
const Color lightChatBackground = Color(0xFFF6F8FA);
const Color lightUserMessageColor = Color(0xFF2188FF);
const Color lightBotMessageColor = Color(0xFFE9EEF3);
const Color lightHintTextColor = Color(0xFF586069);
const Color lightSendButtonColor = Color(0xFF28A745);

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const ChatBotApp(),
    ),
  );
}

class ChatBotApp extends StatelessWidget {
  const ChatBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Personal AI Chatbot",
      themeMode: themeNotifier.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBackground,
          foregroundColor: Colors.black,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatContainer()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? background : lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/chatbot.png', width: 120),
            const SizedBox(height: 20),
            const Text("Personal AI Chatbot",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class ChatContainer extends StatefulWidget {
  const ChatContainer({super.key});
  @override
  State<ChatContainer> createState() => _ChatContainerState();
}

class _ChatContainerState extends State<ChatContainer> {
  final GlobalKey<_ChatScreenState> _chatScreenKey = GlobalKey<_ChatScreenState>();
  bool _isChatOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openChatWithAnimation());
  }

  Route _createPopupRoute() {
    final chatScreen = ChatScreen(key: _chatScreenKey);
    return PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, _) => chatScreen,
      transitionsBuilder: (context, animation, _, child) {
        const curve = Curves.elasticOut;
        var tween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
        return ScaleTransition(scale: animation.drive(tween), child: child);
      },
    );
  }

  void _openChatWithAnimation() {
    if (!mounted) return;
    setState(() => _isChatOpen = true);
    Navigator.of(context).push(_createPopupRoute()).then((_) {
      if (!mounted) return;
      setState(() => _isChatOpen = false);
      _chatScreenKey.currentState?._inactivityTimer?.cancel();
    });
    _chatScreenKey.currentState?._startInactivityTimer();
  }

  void _minimizeChat() {
    if (_isChatOpen) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentBackground = Theme.of(context).brightness == Brightness.dark
        ? background
        : lightBackground;

    if (!_isChatOpen) {
      return Scaffold(
        backgroundColor: currentBackground,
        body: Center(
          child: Lottie.asset(
            'assets/chatbotnew.json',
            width: 420,
            height: 520,
            repeat: true,
            animate: true,
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openChatWithAnimation,
          backgroundColor: sendButtonColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _minimizeChat();
        return false;
      },
      child: Scaffold(backgroundColor: currentBackground, body: const Center()),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  Timer? _inactivityTimer;
  bool _isLoading = false;
  String _selectedLanguage = 'English';

  static const String _pythonApiUrl =
      'https://ai-assistant-blsi.onrender.com/chatbot';

// // For local testing (when Flask runs on your PC)
//   static const String _localApiUrl =
//   // 'http://10.0.2.2:5000/chatbot'
//       'http://10.184.14.38:5000/chatbot';

  static const String _renderApiUrl = 'https://ai-assistant-blsi.onrender.com/chatbot';

  final List<String> _topics = [
    'Health Check-up',
    'Goal Setting',
    'Investing Tips',
    'Fitness Goals',
    'Motivation',
    'Travel',
    'Games',
    'Study-tips',
  ];

  final List<String> _languages = ['English', 'Hindi', 'Kannada'];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'Hi there! I’m your Personal AI assistant.\nAsk me anything or select a topic!',
      isUser: false,
    ));
    _startInactivityTimer();
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: 'Chat reset! I’m your Personal AI assistant.\nHow can I help you today?',
        isUser: false,
      ));
    });
  }

  List<String> _extractOptions(String rawText) {
    final RegExp regex = RegExp(r'<<OPTION:([^>]+)>>');
    return regex.allMatches(rawText).map((m) => m.group(1)!).toList();
  }

  String _cleanText(String rawText) {
    final RegExp regex = RegExp(r'<<OPTION:[^>]+>>');
    return rawText.replaceAll(regex, '').trim();
  }

  // ✅ Updated message sending logic
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    final aiInput = "$text (respond in $_selectedLanguage)";
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();
    _inactivityTimer?.cancel();

    final List<String> endpoints = [_renderApiUrl]; //********_localApiUrl********
    bool success = false;

    for (final url in endpoints) {
      try {
        final response = await http
            .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_input': aiInput,
            'language': _selectedLanguage,
          }),
        )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 405) {
          throw Exception("Server rejected GET method — make sure it's POST route.");
        } else if (response.statusCode != 200) {
          throw Exception("Unexpected status: ${response.statusCode}");
        }

        final Map<String, dynamic> data = jsonDecode(response.body);
        final String rawReply = data['response'] ?? "Sorry, I didn’t get that.";
        final List<String> options = _extractOptions(rawReply);
        final String cleanReply = _cleanText(rawReply);

        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage(text: cleanReply, isUser: false, options: options));
        });

        success = true;
        break;
      } catch (e) {
        debugPrint("Error connecting to $url → $e");
        continue;
      }
    }

    if (!success) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text:
          "⚠️ Unable to connect to the chatbot server.\nCheck if Flask or Render server is running.",
          isUser: false,
        ));
      });
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _scrollToBottom();
    _startInactivityTimer();
  }

  Future<void> _handleLanguageChange(String newLanguage) async {
    setState(() => _selectedLanguage = newLanguage);
    try {
      final response = await http.post(
        Uri.parse(_renderApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_input': "change_language",
          'language': _selectedLanguage,
        }),
      );
      final Map<String, dynamic> data = jsonDecode(response.body);
      final String reply = data['response'] ?? "Language changed.";
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: "Failed to switch language: $e", isUser: false));
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      if (mounted) _sendMessage("auto_reset_scroll");
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Widget _buildMessageWidget(ChatMessage msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alignment = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = msg.isUser
        ? (isDark ? userMessageColor : lightUserMessageColor)
        : (isDark ? botMessageColor : lightBotMessageColor);
    final textColor = isDark ? Colors.white : Colors.black;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment:
          msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(msg.text, style: TextStyle(color: textColor, fontSize: 15)),
            ),
            if (!msg.isUser && msg.options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: msg.options.map((optionText) {
                    return ActionChip(
                      label: Text(optionText,
                          style: TextStyle(
                              color: isDark
                                  ? sendButtonColor
                                  : lightSendButtonColor)),
                      backgroundColor:
                      isDark ? Colors.white : lightBotMessageColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onPressed: () => _sendMessage(optionText),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentChatBackground = isDark ? chatBackground : lightChatBackground;
    final currentBackground = isDark ? background : lightBackground;
    final currentSendButtonColor =
    isDark ? sendButtonColor : lightSendButtonColor;

    return Scaffold(
      backgroundColor: currentChatBackground,
      appBar: AppBar(
        backgroundColor: currentBackground,
        title: const Text("Personal AI Chatbot"),
        centerTitle: true,
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: currentBackground,
              icon: Icon(Icons.language,
                  color: Theme.of(context).appBarTheme.foregroundColor),
              value: _selectedLanguage,
              items: _languages
                  .map((lang) => DropdownMenuItem(
                value: lang,
                child: Text(lang,
                    style: TextStyle(
                        color: Theme.of(context)
                            .appBarTheme
                            .foregroundColor)),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _handleLanguageChange(value);
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh,
                color: Theme.of(context).appBarTheme.foregroundColor),
            tooltip: 'Reset Chat',
            onPressed: _resetChat,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: currentBackground,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: currentSendButtonColor),
              child: const Center(
                child: Text("Personal AI Assistant",
                    style: TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
            ListTile(
              leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                  color: Theme.of(context).textTheme.bodyMedium?.color),
              title: Text('Theme Mode',
                  style: TextStyle(
                      color:
                      Theme.of(context).textTheme.bodyMedium?.color)),
              trailing: Switch(
                value: isDark,
                onChanged: (_) => themeNotifier.toggleTheme(),
                activeColor: currentSendButtonColor,
              ),
            ),
            ListTile(
              leading: Icon(Icons.info,
                  color: Theme.of(context).textTheme.bodyMedium?.color),
              title: Text('About',
                  style: TextStyle(
                      color:
                      Theme.of(context).textTheme.bodyMedium?.color)),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Personal AI Chatbot',
                  applicationVersion: '1.0.0',
                  children: const [
                    Text(
                      "Developed by Team : Hack Street Boys\nYour personal AI assistant powered by Flask + Gemini API.",
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              children: _topics.map((topic) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: ActionChip(
                    label: Text(topic),
                    backgroundColor: isDark
                        ? Colors.blueGrey.shade800
                        : Colors.blueGrey.shade200,
                    labelStyle:
                    TextStyle(color: isDark ? Colors.white : Colors.black87),
                    onPressed: () => _sendMessage(topic),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessageWidget(_messages[index]),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
            color: currentBackground,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle:
                      TextStyle(color: isDark ? hintTextColor : lightHintTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white10
                          : Colors.grey.withOpacity(0.15),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: currentSendButtonColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
