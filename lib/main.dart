import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const serverUrl = 'https://p2p-chat-server-b9dp.onrender.com';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AuthScreen(),
    );
  }
}

// ─── Auth Screen ─────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String? _error;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final endpoint = _isLogin ? '/login' : '/register';
    final res = await http.post(
      Uri.parse('$serverUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      if (_isLogin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              username: body['username'],
              token: body['token'],
            ),
          ),
        );
      } else {
        setState(() {
          _isLogin = true;
          _error = 'Account created! Please log in.';
          _loading = false;
        });
      }
    } else {
      setState(() {
        _error = body['detail'] ?? 'Something went wrong';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('P2P Chat', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_isLogin ? 'Welcome back' : 'Create an account',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 40),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isLogin ? 'Login' : 'Register'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? "Don't have an account? Register" : 'Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final String username;
  final String token;
  const HomeScreen({super.key, required this.username, required this.token});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _publicRooms = [];
  final _roomController = TextEditingController();
  final _inviteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final res = await http.get(Uri.parse('$serverUrl/rooms/public'));
    if (res.statusCode == 200) {
      setState(() {
        _publicRooms = List<String>.from(jsonDecode(res.body)['rooms']);
      });
    }
  }

  Future<void> _createPublicRoom() async {
    if (_roomController.text.trim().isEmpty) return;
    final res = await http.post(
      Uri.parse('$serverUrl/rooms/create-public'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': widget.token, 'room_name': _roomController.text.trim()}),
    );
    if (res.statusCode == 200) {
      _loadRooms();
      _roomController.clear();
    }
  }

  Future<void> _createPrivateRoom() async {
    final res = await http.post(
      Uri.parse('$serverUrl/rooms/create-private'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': widget.token}),
    );
    if (res.statusCode == 200) {
      final code = jsonDecode(res.body)['invite_code'];
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Private Room Created'),
          content: Text('Share this invite code with your friends:\n\n$code'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  void _openRoom(String room, {bool isPrivate = false, String? code}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          username: widget.username,
          token: widget.token,
          room: isPrivate ? code! : room,
          isPrivate: isPrivate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Direct message
            const Text('Direct Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    username: widget.username,
                    token: widget.token,
                    room: null,
                    isPrivate: false,
                  ),
                ),
              ),
              icon: const Icon(Icons.person),
              label: const Text('Open DM'),
            ),

            const SizedBox(height: 24),

            // Public rooms
            const Text('Public Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      hintText: 'New room name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _createPublicRoom, child: const Text('Create')),
                const SizedBox(width: 8),
                IconButton(onPressed: _loadRooms, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 8),
            ..._publicRooms.map((room) => ListTile(
              leading: const Icon(Icons.group),
              title: Text(room),
              onTap: () => _openRoom(room),
            )),

            const SizedBox(height: 24),

            // Private rooms
            const Text('Private Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _createPrivateRoom,
                  icon: const Icon(Icons.lock),
                  label: const Text('Create Private Room'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inviteController,
                    decoration: const InputDecoration(
                      hintText: 'Enter invite code',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_inviteController.text.trim().isEmpty) return;
                    _openRoom('', isPrivate: true, code: _inviteController.text.trim());
                  },
                  child: const Text('Join'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Screen ─────────────────────────────────────────────────────────────

class ChatMessage {
  final String sender;
  final String text;
  final bool isMe;
  final bool isSystem;
  ChatMessage({required this.sender, required this.text, required this.isMe, this.isSystem = false});
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String token;
  final String? room;
  final bool isPrivate;
  const ChatScreen({super.key, required this.username, required this.token, required this.room, required this.isPrivate});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _focusNode = FocusNode();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _peerController = TextEditingController();
  final List<ChatMessage> _messages = [];
  late WebSocketChannel _channel;
  String? _targetPeer;
  bool _joinedRoom = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://p2p-chat-server-b9dp.onrender.com/ws/${widget.token}'),
    );

    _channel.stream.listen((raw) {
      final data = jsonDecode(raw);

      if (data['type'] == 'message') {
        setState(() {
          _messages.add(ChatMessage(sender: data['from'], text: data['text'], isMe: false));
        });
        _scrollToBottom();
      } else if (data['type'] == 'room_message') {
        setState(() {
          _messages.add(ChatMessage(sender: data['from'], text: data['text'], isMe: false));
        });
        _scrollToBottom();
      } else if (data['type'] == 'system') {
        setState(() {
          _messages.add(ChatMessage(sender: 'System', text: data['text'], isMe: false, isSystem: true));
        });
        _joinedRoom = true;
        _scrollToBottom();
      }
    });

    // Auto join room if provided
    if (widget.room != null && widget.room!.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _channel.sink.add(jsonEncode({
          'type': widget.isPrivate ? 'join_private' : 'join_public',
          'room': widget.room,
          'code': widget.room,
        }));
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (widget.room != null && widget.room!.isNotEmpty) {
      _channel.sink.add(jsonEncode({
        'type': 'room_message',
        'from': widget.username,
        'room': widget.room,
        'text': text,
        'is_private': widget.isPrivate,
      }));
    } else {
      if (_targetPeer == null) return;
      _channel.sink.add(jsonEncode({
        'type': 'message',
        'from': widget.username,
        'to': _targetPeer,
        'text': text,
      }));
    }

    setState(() {
      _messages.add(ChatMessage(sender: widget.username, text: text, isMe: true));
    });
    _messageController.clear();
    _scrollToBottom();
    
  }
  
  @override
  void dispose() {
    _focusNode.dispose();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDM = widget.room == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isDM ? 'Direct Message' : (widget.isPrivate ? 'Private Room: ${widget.room}' : 'Room: ${widget.room}')),
      ),
      body: Column(
        children: [
          if (isDM)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _peerController,
                      decoration: const InputDecoration(
                        hintText: "Enter friend's username",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => _targetPeer = _peerController.text.trim()),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),
          if (isDM && _targetPeer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Chatting with: $_targetPeer', style: const TextStyle(color: Colors.greenAccent)),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg.isSystem) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(msg.text, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  );
                }
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg.isMe ? Colors.blueAccent : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(msg.sender, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(msg.text, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    controller: _messageController,
                    focusNode: _focusNode,
                    onSubmitted: (_) => _sendMessage(),
                    
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}