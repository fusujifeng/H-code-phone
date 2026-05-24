import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_config.dart';
import '../theme/theme_provider.dart';
import '../providers/ws_provider.dart';
import '../services/ws_client.dart';

class DrawerSettings extends ConsumerStatefulWidget {
  final ThemeProvider themeProvider;

  const DrawerSettings({
    super.key,
    required this.themeProvider,
  });

  @override
  ConsumerState<DrawerSettings> createState() => _DrawerSettingsState();
}

class _DrawerSettingsState extends ConsumerState<DrawerSettings> {
  final _pairCodeController = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final pairCode = _pairCodeController.text.trim();
    if (pairCode.isEmpty) return;

    setState(() => _connecting = true);
    try {
      await ref.read(wsClientProvider).connectAndRegister(pairCode);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _disconnect() {
    ref.read(wsClientProvider).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ws = ref.watch(wsClientProvider);
    final statusText = ws.status == WsStatus.connected
        ? '已连接'
        : ws.status == WsStatus.connecting
            ? '连接中...'
            : '未连接';

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: theme.colorScheme.surface.withAlpha(240),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('设置',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── 连接 ──
            _buildSection(context, '连接服务器'),
            _buildRow(context, '服务器状态',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ws.status == WsStatus.connected
                            ? const Color(0xFF34C759)
                            : ws.status == WsStatus.connecting
                                ? const Color(0xFFFF9F0A)
                                : const Color(0xFFFF3B30),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(statusText,
                        style: TextStyle(
                            fontSize: 13, color: theme.colorScheme.primary)),
                  ],
                )),
            const SizedBox(height: 8),
            _buildTextField('配对码', _pairCodeController, hint: '6位数字'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    text: _connecting ? '连接中...' : '连接',
                    onTap: _connecting || ws.status == WsStatus.connected ? null : _connect,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (ws.status == WsStatus.connected) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildButton(
                      text: '断开',
                      onTap: _disconnect,
                      color: const Color(0xFFFF3B30),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── 颜色主题 ──
            const Text('颜色主题',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: List.generate(ThemeConfig.all.length, (i) {
                final cfg = ThemeConfig.all[i];
                final isActive = widget.themeProvider.index == i;
                return GestureDetector(
                  onTap: () => widget.themeProvider.setTheme(i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: cfg.surface,
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withAlpha(12),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [cfg.accent, cfg.accent.withAlpha(200)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(cfg.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cfg.fg)),
                        Text(
                          '#${cfg.accent.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                          style:
                              TextStyle(fontSize: 10, color: cfg.muted),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            _buildSection(context, '通用'),
            _buildRow(context, '语音输入',
                trailing: Switch(value: true, onChanged: (_) {})),
            _buildRow(context, '语音语言',
                trailing: const Text('中文（普通话）',
                    style: TextStyle(fontSize: 14))),
            _buildRow(context, '松手自动发送',
                trailing: Switch(value: true, onChanged: (_) {})),
            _buildRow(context, '触觉反馈',
                trailing: Switch(value: true, onChanged: (_) {})),

            _buildSection(context, '关于'),
            _buildRow(context, '版本',
                trailing:
                    const Text('1.0.0', style: TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
    );
  }

  Widget _buildRow(BuildContext context, String label,
      {Widget? trailing}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.onSurface.withAlpha(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String? hint}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.onSurface.withAlpha(20)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(128)),
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(80)),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? color.withAlpha(100) : color,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
