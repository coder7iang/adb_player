import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _appName = 'AdbPlayer';
  static const String _githubUrl = 'https://github.com/coder7iang/adb_player';
  static const String _issuesUrl = 'https://github.com/coder7iang/adb_player/issues';

  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroCard(),
          const SizedBox(height: 20),
          _buildLinksCard(),
          const Spacer(),
          const Center(
            child: Text(
              '© 2026 strong  ·  Released under MIT  ·  Made with Flutter',
              style: TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Image.asset('images/app_icon.png', width: 36, height: 36),
          ),
          const SizedBox(width: 16),
          const Text(
            _appName,
            style: TextStyle(
              color: Color(0xFF101828),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Text(
              _version,
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Expanded(
            child: _LinkItem(
              icon: Icons.code,
              iconColor: const Color(0xFF101828),
              iconBg: const Color(0xFFF2F4F7),
              title: 'GitHub 仓库',
              subtitle: '查看源码 / 提交 PR',
              onTap: () => _open(_githubUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LinkItem(
              icon: Icons.chat_bubble_outline,
              iconColor: const Color(0xFF3B82F6),
              iconBg: const Color(0xFFEFF6FF),
              title: '反馈与建议',
              subtitle: '提交 Issue / 邮件',
              onTap: () => _open(_issuesUrl),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static final BoxDecoration _cardDecoration = BoxDecoration(
    color: Colors.white.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFEAECF0)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF101828).withValues(alpha: 0.03),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

class _LinkItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAECF0)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new,
                size: 14,
                color: Color(0xFF9AA3AE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
