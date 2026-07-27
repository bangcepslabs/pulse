import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatelessWidget {
  static const String supportEmail = 'bum2432@gmail.com';
  static const String websiteUrl = 'https://bangcepslabs.github.io/pulse/';
  static const String privacyUrl =
      'https://bangcepslabs.github.io/pulse/privacy.html';

  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final subtle = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('문의 및 운영 정보'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.22 : 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.support_agent_rounded,
                            color: isDark
                                ? Colors.blue.shade100
                                : const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pulse 고객 지원',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '앱 문의, 운영 정보, 개인정보처리방침을 한곳에서 확인할 수 있습니다.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: subtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _ContactInfoCard(
                          label: '운영 주체',
                          value: 'Bangceps Labs',
                          icon: Icons.apartment_rounded,
                        ),
                        _ContactInfoCard(
                          label: '문의 이메일',
                          value: ContactPage.supportEmail,
                          icon: Icons.mail_outline_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ContactActionTile(
                      icon: Icons.email_rounded,
                      title: '이메일 문의 보내기',
                      subtitle: supportEmail,
                      onTap: () => _openUri(
                        context,
                        Uri(
                          scheme: 'mailto',
                          path: supportEmail,
                          queryParameters: const {
                            'subject': 'Pulse 앱 문의',
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ContactActionTile(
                      icon: Icons.language_rounded,
                      title: '공식 안내 페이지',
                      subtitle: websiteUrl,
                      onTap: () => _openUri(context, Uri.parse(websiteUrl)),
                    ),
                    const SizedBox(height: 10),
                    _ContactActionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: '개인정보처리방침',
                      subtitle: privacyUrl,
                      onTap: () => _openUri(context, Uri.parse(privacyUrl)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '모든 뉴스 콘텐츠는 원문 출처를 함께 표시하며, 자세한 문의는 이메일 또는 공식 안내 페이지를 통해 접수할 수 있습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: subtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openUri(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다.')),
      );
    }
  }
}

class _ContactInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ContactInfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.blue.shade100 : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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

class _ContactActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF172554)
                      : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      isDark ? Colors.blue.shade100 : const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: isDark ? Colors.grey.shade500 : Colors.blueGrey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
