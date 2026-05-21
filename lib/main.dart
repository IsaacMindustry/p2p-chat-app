import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'themes.dart';
import 'theme_notifier.dart';



const serverUrl = 'https://p2p-chat-server-b9dp.onrender.com';

void main() {
  runApp(ChatApp());
}

class ChatApp extends StatefulWidget {
  ChatApp({super.key});

  static final ThemeNotifier themeNotifier = ThemeNotifier();

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  @override
  void initState() {
    super.initState();

    ChatApp.themeNotifier.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '-DST Messenger-',
      debugShowCheckedModeBanner: false,
      theme: ChatApp.themeNotifier.theme,
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
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Password length validation
    if (password.length < 6) {
      setState(() {
        _error = 'Password is too short. Minimum is 6 characters.';
      });
      return;
    }
    if (password.length > 20) {
      setState(() {
        _error = 'Password too long. Maximum is 20 characters.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final endpoint = _isLogin ? '/login' : '/register';

    final res = await http.post(
      Uri.parse('$serverUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
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
                const Text('DST Messenger', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_isLogin ? 'Login' : 'Create an account',
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
                  decoration: const InputDecoration(labelText: 'Password', hintText: '6-20 characters' ,border: OutlineInputBorder()),
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
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  final _roomController = TextEditingController();
  final _inviteController = TextEditingController();
  final _addFriendController = TextEditingController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _loadFriends();
    _loadRequests();
  }

  Future<void> _loadFriends() async {
    final res = await http.get(Uri.parse('$serverUrl/friends/list?token=${widget.token}'));
    if (res.statusCode == 200) {
      setState(() {
        _friends = List<Map<String, dynamic>>.from(jsonDecode(res.body)['friends']);
      });
    }
  }

  Future<void> _loadRequests() async {
    final res = await http.get(Uri.parse('$serverUrl/friends/requests?token=${widget.token}'));
    if (res.statusCode == 200) {
      setState(() {
        _requests = List<Map<String, dynamic>>.from(jsonDecode(res.body)['requests']);
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_addFriendController.text.trim().isEmpty) return;
    final res = await http.post(
      Uri.parse('$serverUrl/friends/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': widget.token, 'to_user': _addFriendController.text.trim()}),
    );
    final body = jsonDecode(res.body);
    _addFriendController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.statusCode == 200 ? 'Friend request sent!' : body['detail'] ?? 'Error')),
    );
  }

  Future<void> _respondToRequest(int id, bool accept) async {
    await http.post(
      Uri.parse('$serverUrl/friends/respond'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': widget.token, 'request_id': id, 'accept': accept}),
    );
    _loadFriends();
    _loadRequests();
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
          content: Text('Invite code:\n\n$code'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  void _openRoom(String room, {bool isPrivate = false, String? code}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        username: widget.username, token: widget.token,
        room: isPrivate ? code! : room, isPrivate: isPrivate,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DST Messenger'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () =>
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()))),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.forum), label: 'Rooms'),
        ],
      ),
      body: _tab == 0 ? _buildFriendsTab() : _buildRoomsTab(),
    );
  }

  Widget _buildFriendsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add friend
          Row(children: [
            Expanded(child: TextField(
              controller: _addFriendController,
              decoration: const InputDecoration(
                hintText: 'Add friend by username',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _sendFriendRequest, child: const Text('Add')),
          ]),

          const SizedBox(height: 16),

          // Pending requests
          if (_requests.isNotEmpty) ...[
            const Text('Pending Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._requests.map((r) => ListTile(
              leading: const Icon(Icons.person_add),
              title: Text(r['from_user']),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _respondToRequest(r['id'], true)),
                IconButton(icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _respondToRequest(r['id'], false)),
              ]),
            )),
            const SizedBox(height: 16),
          ],

          // Friends list
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Friends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _loadFriends, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 8),
          if (_friends.isEmpty)
            const Text('No friends yet — add someone above!', style: TextStyle(color: Colors.white38)),
          ..._friends.map((f) => ListTile(
            leading: CircleAvatar(child: Text(f['username'][0].toUpperCase())),
            title: Text(f['username']),
            subtitle: Text(f['online'] == true ? 'Online' : 'Offline',
              style: TextStyle(color: f['online'] == true ? Colors.greenAccent : Colors.white38)),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatScreen(
                username: widget.username, token: widget.token,
                room: null, isPrivate: false, initialPeer: f['username'],
              ),
            )),
          )),
        ],
      ),
    );
  }

  Widget _buildRoomsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Public Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                hintText: 'New room name', border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _createPublicRoom, child: const Text('Create')),
            const SizedBox(width: 8),
            IconButton(onPressed: _loadRooms, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 8),
          ..._publicRooms.map((room) => ListTile(
            leading: const Icon(Icons.group),
            title: Text(room),
            onTap: () => _openRoom(room),
          )),
          const SizedBox(height: 24),
          const Text('Private Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _createPrivateRoom,
            icon: const Icon(Icons.lock), label: const Text('Create Private Room')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _inviteController,
              decoration: const InputDecoration(
                hintText: 'Enter invite code', border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (_inviteController.text.trim().isEmpty) return;
                _openRoom('', isPrivate: true, code: _inviteController.text.trim());
              },
              child: const Text('Join'),
            ),
          ]),
        ],
      ),
    );
  }
}
// ─── Settings Screen ─────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Dark Theme"),
            onTap: () {
              ChatApp.themeNotifier.setTheme(AppThemes.darkTheme);
            },
          ),
          ListTile(
            title: const Text("Midnight Purple"),
            onTap: () {
              ChatApp.themeNotifier.setTheme(AppThemes.midnightTheme);
            },
          ),
          ListTile(
            title: const Text("Light Theme"),
            onTap: () {
              ChatApp.themeNotifier.setTheme(AppThemes.lightTheme);
            },
          ),
        ],
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
  final String? initialPeer;
  const ChatScreen({super.key, required this.username, required this.token, required this.room, required this.isPrivate, this.initialPeer});

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
    if (widget.initialPeer != null) {
      _targetPeer = widget.initialPeer;
      _peerController.text = widget.initialPeer!;
      Future.delayed(const Duration(milliseconds: 600), () {
        _loadHistory(widget.initialPeer!);
      });
    }
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
  Future<void> _loadHistory(String otherUser) async {
    final res = await http.get(
      Uri.parse('$serverUrl/messages/history?token=${widget.token}&other_user=$otherUser'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final history = data['messages'] as List;
      setState(() {
        for (final msg in history) {
          _messages.add(ChatMessage(
            sender: msg['from'],
            text: msg['text'],
            isMe: msg['from'] == widget.username,
          ));
        }
      });
      _scrollToBottom();
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
                        hintText: "Enter username",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _targetPeer = _peerController.text.trim());
                      _loadHistory(_peerController.text.trim());
                    },
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
                      hintText: 'Message...',
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