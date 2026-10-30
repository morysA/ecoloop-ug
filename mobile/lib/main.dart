import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

void main() => runApp(const EcoLoopApp());

const ecoGreen = Color(0xFF16845B);
const ecoDark = Color(0xFF103D2D);
const ecoMint = Color(0xFFE8F6EE);
const ecoBackground = Color(0xFFF6F8F6);

class EcoLoopApp extends StatelessWidget {
  const EcoLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: ecoGreen, brightness: Brightness.light);
    return MaterialApp(
      title: 'EcoLoop UG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: ecoBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: ecoBackground,
          foregroundColor: ecoDark,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.black.withOpacity(.07))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: ecoGreen, width: 1.5)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.black.withOpacity(.045))),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ecoGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _location = TextEditingController();
  String _role = 'household';
  bool _register = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  static const _roles = <String, String>{
    'household': 'Household / resident',
    'collector': 'Waste collector',
    'recycler': 'Recycling business',
    'organization': 'Community organization',
  };

  @override
  void dispose() {
    _fullName.dispose(); _username.dispose(); _email.dispose(); _password.dispose();
    _confirmPassword.dispose(); _location.dispose();
    super.dispose();
  }

  void _switchMode(bool register) {
    setState(() { _register = register; _error = null; });
  }

  String _serverMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    return 'Request failed (${response.statusCode}). Please try again.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final uri = Uri.parse('$apiBaseUrl/api/v1/auth/${_register ? 'register' : 'login'}');
      final payload = _register
          ? <String, dynamic>{
              'full_name': _fullName.text.trim(),
              'username': _username.text.trim(),
              'email': _email.text.trim().toLowerCase(),
              'password': _password.text,
              'role': _role,
              'location_label': _location.text.trim(),
            }
          : <String, dynamic>{'email': _email.text.trim().toLowerCase(), 'password': _password.text};
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = Map<String, dynamic>.from(data['user'] as Map);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => EcoHomeScreen(
            userName: (user['full_name'] ?? user['username'] ?? 'EcoLoop member').toString(),
            userId: (user['id'] ?? '').toString(),
            userRole: (user['role'] ?? 'household').toString(),
            userLocation: (user['location_label'] ?? '').toString(),
          ),
        ));
      } else if (!_register && response.statusCode == 401) {
        setState(() { _register = true; _error = 'We could not find a matching account. Create your EcoLoop account below to get started.'; });
      } else {
        setState(() => _error = _serverMessage(response));
      }
    } catch (_) {
      setState(() => _error = 'EcoLoop could not reach the server. Check that the backend is running and your API address is correct.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return Center(child: SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 30 : 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1080 : 520),
            child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const Expanded(flex: 11, child: _WelcomePanel()), const SizedBox(width: 34),
                  Expanded(flex: 10, child: _formPanel()),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const _WelcomePanel(compact: true), const SizedBox(height: 25), _formPanel(),
                ]),
          ),
        ));
      })),
    );
  }

  Widget _formPanel() => Form(
    key: _formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: ecoMint, borderRadius: BorderRadius.circular(30)),
        child: const Text('YOUR COMMUNITY. YOUR IMPACT.', style: TextStyle(color: ecoDark, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
      ),
      const SizedBox(height: 16),
      Text(_register ? 'Join the loop.' : 'Good to see you.', style: const TextStyle(fontSize: 32, height: 1.08, fontWeight: FontWeight.w900, color: ecoDark, letterSpacing: -1.0)),
      const SizedBox(height: 9),
      Text(_register ? 'Create your profile so the right people and recycling opportunities can find you.' : 'Sign in to turn everyday waste into community value.', style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
      const SizedBox(height: 22),
      if (_error != null) ...[
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(14)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, color: Color(0xFF9A481B)), const SizedBox(width: 9), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFF793A16), height: 1.4)))])),
        const SizedBox(height: 14),
      ],
      if (_register) ...[
        TextFormField(controller: _fullName, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)), validator: (v) => v == null || v.trim().length < 2 ? 'Enter your full name' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _username, textInputAction: TextInputAction.next, autocorrect: false, decoration: const InputDecoration(labelText: 'Choose a username', prefixIcon: Icon(Icons.alternate_email)), validator: (v) { final s = (v ?? '').trim(); return !RegExp(r'^[a-zA-Z0-9_.]{3,24}$').hasMatch(s) ? 'Use 3–24 letters, numbers, dots or underscores' : null; }),
        const SizedBox(height: 12),
      ],
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autocorrect: false, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)), validator: (v) => v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? 'Enter a valid email address' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _password, obscureText: _hidePassword, textInputAction: _register ? TextInputAction.next : TextInputAction.done, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 8 ? 'Use at least 8 characters' : null),
      if (_register) ...[
        const SizedBox(height: 12),
        TextFormField(controller: _confirmPassword, obscureText: true, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined)), validator: (v) => v != _password.text ? 'Passwords do not match' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _role, isExpanded: true, decoration: const InputDecoration(labelText: 'I am joining as', prefixIcon: Icon(Icons.groups_2_outlined)), items: _roles.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _role = v ?? 'household')),
        const SizedBox(height: 12),
        TextFormField(controller: _location, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Current area / town', hintText: 'e.g. Ntinda, Kampala', prefixIcon: Icon(Icons.location_on_outlined), helperText: 'Enter an area, not your exact home address.'), validator: (v) => v == null || v.trim().length < 2 ? 'Enter your current area or town' : null),
        const SizedBox(height: 7),
        Text('Your profile helps match you with nearby recycling activity. You can use a neighbourhood or town for privacy.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4)),
      ],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (_busy) ...[const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 10)], Text(_busy ? 'Please wait…' : (_register ? 'Create my EcoLoop account' : 'Sign in securely')), if (!_busy) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 18)]]))),
      const SizedBox(height: 13),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Flexible(child: Text(_register ? 'Already part of EcoLoop?' : 'New here?', style: TextStyle(color: Colors.grey.shade700))), TextButton(onPressed: _busy ? null : () => _switchMode(!_register), child: Text(_register ? 'Sign in' : 'Create an account', style: const TextStyle(fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 6),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_outlined, size: 14, color: ecoGreen), SizedBox(width: 6), Flexible(child: Text('Your account is checked by the EcoLoop server.', style: TextStyle(fontSize: 11, color: ecoDark)))]),
    ]),
  );
}

class _WelcomePanel extends StatelessWidget {
  final bool compact;
  const _WelcomePanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 22 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF145A40), Color(0xFF16845B), Color(0xFF50A879)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 31)),
        const SizedBox(height: 23),
        const Text('EcoLoop UG', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -.7)),
        const SizedBox(height: 9),
        const Text('Waste less. Recover more.\nBuild a cleaner tomorrow.', style: TextStyle(color: Colors.white, fontSize: 18, height: 1.4, fontWeight: FontWeight.w500)),
        const SizedBox(height: 22),
        Row(children: [
          const Icon(Icons.eco_outlined, color: Colors.white70), const SizedBox(width: 9),
          Expanded(child: Text('Connect households, collectors and recycling opportunities in one place.', style: TextStyle(color: Colors.white.withOpacity(.9), height: 1.5))),
        ]),
        if (!compact) ...[
          const SizedBox(height: 30),
          const Wrap(spacing: 8, runSpacing: 8, children: [
            _Pill(label: 'Recycle smarter'), _Pill(label: 'Track your impact'), _Pill(label: 'Community support'),
          ]),
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(30)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)));
}

class EcoHomeScreen extends StatefulWidget {
  final String userName;
  final String userId;
  final String userRole;
  final String userLocation;
  const EcoHomeScreen({super.key, required this.userName, this.userId = '', this.userRole = 'household', this.userLocation = ''});
  @override
  State<EcoHomeScreen> createState() => _EcoHomeScreenState();
}

class _EcoHomeScreenState extends State<EcoHomeScreen> {
  int _index = 0;
  bool _loading = false;
  bool _apiOnline = false;
  String? _loadError;
  List<Map<String, dynamic>> _listings = [];

  static const _categories = <String, String>{
    'Plastic': 'plastic',
    'Paper & cardboard': 'paper',
    'Metal': 'metal',
    'Glass': 'glass',
    'Organic': 'organic',
  };

  @override
  void initState() {
    super.initState();
    _loadListings();
    _checkApi();
  }

  Future<void> _checkApi() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/health')).timeout(const Duration(seconds: 4));
      if (mounted) setState(() => _apiOnline = response.statusCode >= 200 && response.statusCode < 300);
    } catch (_) {
      if (mounted) setState(() => _apiOnline = false);
    }
  }

  Future<void> _loadListings() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/v1/listings')).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Server returned ${response.statusCode}');
      final decoded = jsonDecode(response.body);
      final raw = decoded is List ? decoded : (decoded is Map ? (decoded['items'] ?? decoded['listings'] ?? []) : []);
      final parsed = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          final categoryId = (item['category_id'] ?? 'plastic').toString();
          parsed.add({
            ...Map<String, dynamic>.from(item),
            'category': _categoryLabel(categoryId),
            'quantity': '${item['quantity_kg'] ?? item['quantity'] ?? 0} kg',
            'status': (item['status'] ?? 'available').toString(),
            'location': (item['location_label'] ?? item['location'] ?? 'Location not specified').toString(),
            'icon': _categoryIcon(categoryId),
          });
        }
      }
      if (mounted) setState(() { _listings = parsed; _apiOnline = true; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _apiOnline = false; _loadError = 'Could not load listings. Check that the EcoLoop API is running.'; });
    }
  }

  String _categoryLabel(String id) => _categories.entries.where((e) => e.value == id).map((e) => e.key).firstOrNull ?? id;
  IconData _categoryIcon(String id) {
    switch (id) {
      case 'paper': return Icons.inventory_2_outlined;
      case 'metal': return Icons.hardware_outlined;
      case 'glass': return Icons.wine_bar_outlined;
      case 'organic': return Icons.compost_outlined;
      default: return Icons.recycling_rounded;
    }
  }

  Future<void> _showAddListingDialog() async {
    final formKey = GlobalKey<FormState>();
    final quantity = TextEditingController();
    final location = TextEditingController();
    final description = TextEditingController();
    String category = 'Plastic';
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('List recyclable waste', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Waste category'), items: _categories.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setDialogState(() => category = v ?? 'Plastic')),
          const SizedBox(height: 12),
          TextFormField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Estimated quantity (kg)', prefixIcon: Icon(Icons.scale_outlined)), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n <= 0 ? 'Enter a quantity above zero' : null; }),
          const SizedBox(height: 12),
          TextFormField(controller: location, decoration: const InputDecoration(labelText: 'Collection area', hintText: 'e.g. Ntinda, Kampala', prefixIcon: Icon(Icons.location_on_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a collection area' : null),
          const SizedBox(height: 12),
          TextFormField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)', prefixIcon: Icon(Icons.notes_outlined))),
        ])))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton.icon(onPressed: saving ? null : () async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() => saving = true);
            try {
              final response = await http.post(Uri.parse('$apiBaseUrl/api/v1/listings'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({
                'household_id': widget.userId.isEmpty ? 'unassigned-user' : widget.userId,
                'category_id': _categories[category],
                'quantity_kg': double.parse(quantity.text.trim()),
                'description': description.text.trim(),
                'location_label': location.text.trim(),
              })).timeout(const Duration(seconds: 10));
              if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Server returned ${response.statusCode}');
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _loadListings();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waste listing saved successfully.')));
            } catch (_) {
              setDialogState(() => saving = false);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save listing. Check the API and try again.')));
            }
          }, icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add), label: Text(saving ? 'Saving…' : 'Publish listing')),
        ],
      )),
    );
    quantity.dispose(); location.dispose(); description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Overview', 'Learn', 'My impact', 'Support'];
    final pages = <Widget>[
      _DashboardPage(userName: widget.userName, listings: _listings, loading: _loading, error: _loadError, apiOnline: _apiOnline, onAdd: _showAddListingDialog, onRefresh: _loadListings, onBrowse: () => setState(() => _index = 2)),
      const _LearnPage(),
      _ImpactPage(listings: _listings),
      const SupportChatPage(),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      return Scaffold(
        appBar: AppBar(title: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: ecoMint, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.recycling_rounded, color: ecoGreen)), const SizedBox(width: 10), const Text('EcoLoop', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.5)), const SizedBox(width: 6), const Text('UG', style: TextStyle(color: ecoGreen, fontWeight: FontWeight.w800, fontSize: 13))]),
          actions: [Padding(padding: const EdgeInsets.only(right: 14), child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: _apiOnline ? ecoMint : const Color(0xFFFFF1DD), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.circle, size: 8, color: _apiOnline ? ecoGreen : Colors.orange.shade800), const SizedBox(width: 6), Text(_apiOnline ? 'API connected' : 'Offline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _apiOnline ? ecoDark : Colors.orange.shade900))]))),),
          ],
        ),
        body: Row(children: [
          if (wide) NavigationRail(extended: constraints.maxWidth >= 1050, selectedIndex: _index, onDestinationSelected: (v) => setState(() => _index = v), labelType: constraints.maxWidth >= 1050 ? NavigationRailLabelType.none : NavigationRailLabelType.all, destinations: const [NavigationRailDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: Text('Home')), NavigationRailDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: Text('Learn')), NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: Text('Impact')), NavigationRailDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: Text('Support'))]),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ]),
        bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: _index, onDestinationSelected: (v) => setState(() => _index = v), destinations: const [NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'), NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Learn'), NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Impact'), NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Support')]),
        floatingActionButton: _index == 0 ? FloatingActionButton.extended(onPressed: _showAddListingDialog, backgroundColor: ecoGreen, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('List waste')) : null,
      );
    });
  }
}

class _DashboardPage extends StatelessWidget {
  final String userName;
  final List<Map<String, dynamic>> listings;
  final bool loading;
  final String? error;
  final bool apiOnline;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;
  final VoidCallback onBrowse;
  const _DashboardPage({required this.userName, required this.listings, required this.loading, required this.error, required this.apiOnline, required this.onAdd, required this.onRefresh, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width >= 900 ? 32.0 : 18.0;
    final totalKg = listings.fold<double>(0, (sum, item) => sum + (double.tryParse((item['quantity_kg'] ?? 0).toString()) ?? 0));
    return RefreshIndicator(onRefresh: onRefresh, child: ListView(padding: EdgeInsets.fromLTRB(pad, 12, pad, 100), children: [
      Text('Hello, $userName 👋', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ecoDark, letterSpacing: -.7)),
      const SizedBox(height: 5), Text('Small actions. A cleaner community.', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            colors: [Color(0xFF124E37), Color(0xFF19845B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Turn waste into value',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'List recyclable materials and help them find a new purpose.',
                    style: TextStyle(color: Colors.white.withOpacity(.85), height: 1.45),
                  ),
                  const SizedBox(height: 17),
                  FilledButton.tonalIcon(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ecoDark,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create a listing'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.recycling_rounded, size: 72, color: Colors.white24),
          ],
        ),
      ),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, c) { final cols = c.maxWidth > 700 ? 3 : 1; final items = [ _MetricCard(icon: Icons.inventory_2_outlined, label: 'Active listings', value: '${listings.length}', tint: ecoMint), _MetricCard(icon: Icons.scale_outlined, label: 'Waste listed', value: '${totalKg.toStringAsFixed(1)} kg', tint: const Color(0xFFEAF0FF)), _MetricCard(icon: Icons.location_on_outlined, label: 'Community', value: 'Uganda', tint: const Color(0xFFFFF0DD)) ]; if (cols == 1) return Column(children: items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: e)).toList()); return Row(children: items.map((e) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: e))).toList()); }),
      const SizedBox(height: 26),
      Row(children: [const Expanded(child: Text('Recent listings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ecoDark))), TextButton(onPressed: onBrowse, child: const Text('View impact'))]),
      const SizedBox(height: 10),
      if (loading && listings.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
      if (error != null && listings.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [const Icon(Icons.cloud_off_outlined, size: 35, color: Colors.orange), const SizedBox(height: 8), Text(error!, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Try again'))]))),
      if (!loading && listings.isEmpty && error == null) Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Container(width: 58, height: 58, decoration: const BoxDecoration(color: ecoMint, shape: BoxShape.circle), child: const Icon(Icons.recycling_rounded, color: ecoGreen, size: 30)), const SizedBox(height: 12), const Text('Your recycling journey starts here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 5), Text('There are no listings yet. Add your first recyclable item.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)), const SizedBox(height: 14), OutlinedButton(onPressed: onAdd, child: const Text('List your first item'))]))),
      ...listings.take(8).map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ListingTile(item: item))),
      if (listings.isNotEmpty && !apiOnline) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Showing last loaded data. API connection is currently unavailable.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
    ]));
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _MetricCard({required this.icon, required this.label, required this.value, required this.tint});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(17), child: Row(children: [Container(width: 45, height: 45, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: ecoGreen)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: ecoDark))]))])));
}

class _ListingTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ListingTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final category = (item['category'] ?? 'Recyclables').toString();
    final quantity = (item['quantity'] ?? '${item['quantity_kg'] ?? 0} kg').toString();
    final status = (item['status'] ?? 'available').toString();
    return Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: ecoMint, borderRadius: BorderRadius.circular(15)), child: Icon(item['icon'] is IconData ? item['icon'] as IconData : Icons.recycling, color: ecoGreen)), title: Text(category, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('${item['location'] ?? item['location_label'] ?? 'Location not specified'} · $quantity', maxLines: 2, overflow: TextOverflow.ellipsis)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: ecoMint, borderRadius: BorderRadius.circular(20)), child: Text(status, style: const TextStyle(color: ecoDark, fontSize: 10, fontWeight: FontWeight.w800)))));
  }
}

class _LearnPage extends StatelessWidget {
  const _LearnPage();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Learn to recycle', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ecoDark)),
    const SizedBox(height: 7), Text('Simple habits make a meaningful difference.', style: TextStyle(color: Colors.grey.shade700)),
    const SizedBox(height: 20),
    const _LearningCard(icon: Icons.recycling, color: Color(0xFFE5F5EB), title: 'Plastic', subtitle: 'Rinse containers when possible, keep them dry and separate different materials.'),
    const SizedBox(height: 12), const _LearningCard(icon: Icons.inventory_2_outlined, color: Color(0xFFEAF0FF), title: 'Paper & cardboard', subtitle: 'Keep paper clean and dry. Flatten cardboard boxes to save storage space.'),
    const SizedBox(height: 12), const _LearningCard(icon: Icons.hardware_outlined, color: Color(0xFFFFF0DD), title: 'Metal', subtitle: 'Separate cans and scrap metal. Handle sharp edges carefully.'),
    const SizedBox(height: 12), const _LearningCard(icon: Icons.wine_bar_outlined, color: Color(0xFFF2EAFE), title: 'Glass', subtitle: 'Keep glass separate and pack broken glass safely before handing it over.'),
    const SizedBox(height: 12), const _LearningCard(icon: Icons.compost_outlined, color: Color(0xFFEAF5D9), title: 'Organic waste', subtitle: 'Food scraps and garden waste may be suitable for composting where available.'),
    const SizedBox(height: 18), Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline, color: ecoGreen, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Remember', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 5), Text('Follow your local collector’s instructions. Never mix hazardous or medical waste with ordinary recyclables.', style: TextStyle(height: 1.45, color: Colors.grey.shade700))]))]))),
  ]);
}

class _LearningCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _LearningCard({required this.icon, required this.color, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(17), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: ecoGreen)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Colors.grey.shade700, height: 1.45))]))])));
}

class _ImpactPage extends StatelessWidget {
  final List<Map<String, dynamic>> listings;
  const _ImpactPage({required this.listings});
  @override
  Widget build(BuildContext context) {
    final totalKg = listings.fold<double>(0, (sum, item) => sum + (double.tryParse((item['quantity_kg'] ?? 0).toString()) ?? 0));
    final byCategory = <String, int>{};
    for (final item in listings) { final name = (item['category'] ?? 'Other').toString(); byCategory[name] = (byCategory[name] ?? 0) + 1; }
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Your impact', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ecoDark)),
      const SizedBox(height: 7), Text('A snapshot of the recyclable waste recorded in EcoLoop.', style: TextStyle(color: Colors.grey.shade700)),
      const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: ecoDark, borderRadius: BorderRadius.circular(25)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.eco_outlined, color: Color(0xFF91D6A9), size: 34), const SizedBox(height: 18), Text('${totalKg.toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('Total quantity listed', style: TextStyle(color: Colors.white.withOpacity(.8))), const SizedBox(height: 17), LinearProgressIndicator(value: (totalKg / 100).clamp(0, 1), minHeight: 7, backgroundColor: Colors.white24, color: const Color(0xFF91D6A9)), const SizedBox(height: 8), Text('Progress display only — environmental benefits are not yet calculated.', style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11))])),
      const SizedBox(height: 18),
      _MetricCard(icon: Icons.inventory_2_outlined, label: 'Listings created', value: '${listings.length}', tint: ecoMint),
      const SizedBox(height: 18), const Text('Materials breakdown', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ecoDark)),
      const SizedBox(height: 10),
      if (byCategory.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Your category breakdown will appear after you create your first listing.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        )
      else
        ...byCategory.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.recycling, color: ecoGreen),
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(
                  '${e.value} listing${e.value == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});
  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _ChatMessage {
  final String text;
  final DateTime time;
  final bool fromUser;
  _ChatMessage(this.text, this.time, this.fromUser);
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage('Welcome to EcoLoop support! 👋', DateTime.now(), false),
    _ChatMessage('Ask us about listing recyclable waste, collection areas or using the app.', DateTime.now(), false),
  ];

  @override
  void dispose() { _controller.dispose(); _scrollController.dispose(); super.dispose(); }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() { _messages.add(_ChatMessage(text, DateTime.now(), true)); _controller.clear(); });
    WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut); });
  }

  String _time(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(color: ecoMint, shape: BoxShape.circle),
            child: const Icon(Icons.support_agent, color: ecoGreen, size: 29),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EcoLoop Support',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ecoDark),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: ecoGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Support chat preview',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const Divider(height: 1),
    Expanded(child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(18), itemCount: _messages.length, itemBuilder: (context, index) { final m = _messages[index]; return Align(alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11), decoration: BoxDecoration(color: m.fromUser ? ecoGreen : Colors.white, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(m.fromUser ? 18 : 5), bottomRight: Radius.circular(m.fromUser ? 5 : 18)), border: m.fromUser ? null : Border.all(color: Colors.black.withOpacity(.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Align(alignment: Alignment.centerLeft, child: Text(m.text, style: TextStyle(color: m.fromUser ? Colors.white : ecoDark, height: 1.4))), const SizedBox(height: 4), Text(_time(m.time), style: TextStyle(fontSize: 10, color: m.fromUser ? Colors.white70 : Colors.grey.shade500))]))); })),
    Container(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE9EDE9)))), child: SafeArea(top: false, child: Row(children: [Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Write a message…', prefixIcon: Icon(Icons.chat_bubble_outline)))), const SizedBox(width: 9), IconButton.filled(onPressed: _send, style: IconButton.styleFrom(backgroundColor: ecoGreen, foregroundColor: Colors.white, minimumSize: const Size(50, 50)), icon: const Icon(Icons.send_rounded))]))),
    Container(color: const Color(0xFFFFF3DE), width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), child: const Text('Preview only: messages stay on this device until a chat backend is added.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF7A551E))),),
  ]);
}
