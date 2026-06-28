import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_chat/login/login_bloc.dart';
import 'package:simple_chat/login/login_event.dart';
import 'package:simple_chat/login/login_state.dart';
import 'package:simple_chat/main_page/main_page_widget.dart';

const List<Map<String, dynamic>> kPublicServers = [
  {'name': 'xmpp.jp', 'domain': 'xmpp.jp', 'port': 5222},
  {'name': '404.city', 'domain': '404.city', 'port': 5222},
  {'name': 'jabber.org', 'domain': 'jabber.org', 'port': 5222},
  {'name': 'conversations.im', 'domain': 'conversations.im', 'port': 5222},
  {'name': 'jabber.de', 'domain': 'jabber.de', 'port': 5222},
  {'name': 'draugr.de', 'domain': 'draugr.de', 'port': 5222},
  {'name': 'magicbroccoli.de', 'domain': 'magicbroccoli.de', 'port': 5222},
  {'name': 'yax.im', 'domain': 'yax.im', 'port': 5222},
  {'name': 'jabber.fr', 'domain': 'jabber.fr', 'port': 5222},
];

class LoginForm extends StatefulWidget {
  final LoginBloc loginBloc;
  const LoginForm({Key? key, required this.loginBloc}) : super(key: key);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _domainController = TextEditingController();
  final _portController = TextEditingController();
  bool _rememberMe = false;
  bool _isExtended = false;
  bool _isRegisterMode = false;
  String? _authMessage;

  LoginBloc get _loginBloc => widget.loginBloc;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _showServerPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Servidores públicos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          ...kPublicServers.map((s) => ListTile(
            leading: const Icon(Icons.dns, color: Colors.lightBlueAccent),
            title: Text(s['name'] as String),
            subtitle: Text('porta ${s['port']}'),
            onTap: () {
              _domainController.text = s['domain'] as String;
              _portController.text = s['port'].toString();
              if (!_isExtended) setState(() => _isExtended = true);
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _onLoginPressed() {
    _loginBloc.add(LoginButtonPressed(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      domain: _domainController.text.trim(),
      port: int.tryParse(_portController.text) ?? 5222,
    ));
  }

  void _onRegisterPressed() {
    final parts = _usernameController.text.trim().split('@');
    final username = parts[0];
    final domain = _isExtended && _domainController.text.isNotEmpty
        ? _domainController.text.trim()
        : (parts.length > 1 ? parts[1] : '');
    if (username.isEmpty || domain.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _authMessage = 'Preencha usuário, senha e servidor');
      return;
    }
    _loginBloc.add(RegisterButtonPressed(
      username: username,
      password: _passwordController.text,
      domain: domain,
      port: int.tryParse(_portController.text) ?? 5222,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      bloc: _loginBloc,
      listener: (context, state) {
        if (state is LoginDataLoaded) {
          _portController.text = state.port.toString();
          _usernameController.text = state.username;
          _passwordController.text = state.password;
          _domainController.text = state.domain;
          _rememberMe = state.rememberMe;
          _isExtended = state.wasExtended;
          _authMessage = null;
          // 🔽 REMOVIDO const – construtor não é constante
          _loginBloc.add(LoginDataShownEvent());
        } else if (state is RememberMeChanged) {
          _rememberMe = state.rememberMeValue;
        } else if (state is LoginExtendedChanged) {
          _isExtended = state.loginExtendValue;
        } else if (state is LoginFailure) {
          _authMessage = state.message;
        } else if (state is RegisterFailure) {
          _authMessage = state.message;
        } else if (state is RegisterSuccess) {
          _authMessage = null;
          // 🔽 REMOVIDO const – construtor não é constante
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Conta criada! Entrando...'), backgroundColor: Colors.green)
          );
        } else if (state is LoginSuccess) {
          Navigator.pushReplacementNamed(context, MainPage.TAG);
        } else if (state is LoginLoading) {
          _authMessage = null;
        }
      },
      builder: (context, state) {
        if (state is RegisterLoading) return _buildLoading('Criando conta...');
        if (state is LoginLoading) return _buildLoading('Conectando...');
        return _buildForm();
      },
    );
  }

  Widget _buildLoading(String msg) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent)),
    const SizedBox(height: 16),
    Text(msg, style: const TextStyle(color: Colors.blueGrey)),
  ]));

  Widget _buildForm() {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 40),
        const Text('Simple Chat', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 36, color: Colors.lightBlueAccent)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: () => setState(() { _isRegisterMode = false; _authMessage = null; }), child: Text('Entrar', style: TextStyle(color: !_isRegisterMode ? Colors.lightBlueAccent : Colors.grey, fontWeight: !_isRegisterMode ? FontWeight.bold : FontWeight.normal))),
          const Text('|', style: TextStyle(color: Colors.grey)),
          TextButton(onPressed: () => setState(() { _isRegisterMode = true; _authMessage = null; if (!_isExtended) _isExtended = true; }), child: Text('Criar conta', style: TextStyle(color: _isRegisterMode ? Colors.lightBlueAccent : Colors.grey, fontWeight: _isRegisterMode ? FontWeight.bold : FontWeight.normal))),
        ]),
        const SizedBox(height: 24),
        TextFormField(
          controller: _usernameController,
          keyboardType: _isExtended ? TextInputType.text : TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: _isExtended ? 'usuário' : 'usuario@servidor.com',
            prefixIcon: const Icon(Icons.person_outline),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(32)),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _passwordController, obscureText: true, decoration: InputDecoration(hintText: 'Senha', prefixIcon: const Icon(Icons.lock_outline), contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(32)))),
        const SizedBox(height: 12),
        if (_isExtended) ...[
          Row(children: [
            Expanded(flex: 3, child: TextFormField(controller: _domainController, decoration: InputDecoration(hintText: 'servidor', prefixIcon: const Icon(Icons.dns_outlined), contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(32))))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _portController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: '5222', contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(32))))),
          ]),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _showServerPicker, icon: const Icon(Icons.list, color: Colors.blueAccent), label: const Text('Escolher servidor público', style: TextStyle(color: Colors.blueAccent))),
          const SizedBox(height: 4),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Checkbox(value: _rememberMe, onChanged: (v) => _loginBloc.add(RememberMePressed(rememberMeValue: v ?? false))),
            const Text('Lembrar'),
          ]),
          TextButton(onPressed: () => _loginBloc.add(ExtendPressed()), child: Text(_isExtended ? 'Básico' : 'Avançado', style: const TextStyle(color: Colors.blueAccent))),
        ]),
        if (_authMessage != null && _authMessage!.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_authMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ElevatedButton(
          onPressed: _isRegisterMode ? _onRegisterPressed : _onLoginPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.all(14)),
          child: Text(_isRegisterMode ? 'Criar conta' : 'Entrar', style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        const SizedBox(height: 12),
        if (!_isRegisterMode)
          TextButton(
            onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text('Esqueceu a senha?'),
              content: Text('Acesse o site do servidor "${_domainController.text.trim().isNotEmpty ? _domainController.text.trim() : 'seu servidor'}" para recuperar sua senha.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            )),
            child: const Text('Esqueceu a senha?', style: TextStyle(color: Colors.blueGrey)),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
