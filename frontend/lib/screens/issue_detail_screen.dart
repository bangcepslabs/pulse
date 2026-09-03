import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trend_insight.dart';
import '../models/trend_item.dart';
import '../widgets/network_thumbnail.dart';

class IssueDetailScreen extends StatelessWidget {
  final EditionIssue issue;
  final Future<List<TrendItem>> articlesFuture;

  const IssueDetailScreen({
    super.key,
    required this.issue,
    required this.articlesFuture,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final title = _issueDisplayTitle(issue);
    final summary = _usableSummary(issue.summary, title);
    final keyPoints = issue.timeline.where((item) => item.isUsable).toList();
    final imageUrl = issue.thumbnailUrl.trim();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 20,
        title: Text(
          '이슈 상세',
          style: TextStyle(
            color: foreground,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor:
            isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FB),
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: border, height: 1),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<TrendItem>>(
          future: articlesFuture,
          builder: (context, snapshot) {
            final articles =
                _sortedArticles(snapshot.data ?? const <TrendItem>[]);
            return CustomScrollView(
              slivers: [
                if (MediaQuery.sizeOf(context).width < 0)
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: '뒤로 가기',
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: Icon(Icons.arrow_back_rounded,
                                    color: foreground),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 0 : 20,
                          isDesktop ? 18 : 8,
                          isDesktop ? 0 : 20,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IssueDetailMeta(
                              category: issue.category,
                              time: _issueDetailTimeLabel(issue.lastSeenAt),
                              muted: muted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title.isEmpty ? '주요 이슈' : title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foreground,
                                fontSize: isDesktop ? 34 : 24,
                                height: isDesktop ? 1.18 : 1.28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (imageUrl.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: NetworkThumbnail(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    loadingWidget: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1F2937)
                                            : const Color(0xFFF1F5F9),
                                      ),
                                    ),
                                    errorWidget: const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                            if (summary != null) ...[
                              const SizedBox(height: 24),
                              _IssueDetailHeading(
                                  title: '무슨 일이 있었나', color: foreground),
                              const SizedBox(height: 10),
                              Text(
                                summary,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: isDesktop ? 16 : 15,
                                  height: 1.65,
                                ),
                              ),
                            ],
                            if (keyPoints.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Divider(color: border, height: 1),
                              const SizedBox(height: 22),
                              _IssueDetailHeading(
                                  title: '이슈 흐름', color: foreground),
                              const SizedBox(height: 12),
                              ...keyPoints.map(
                                (event) => _IssueDetailTimelineRow(
                                  event: event,
                                  muted: muted,
                                  foreground: foreground,
                                ),
                              ),
                            ],
                            const SizedBox(height: 26),
                            Divider(color: border, height: 1),
                            const SizedBox(height: 20),
                            _IssueDetailHeading(
                              title:
                                  '관련 기사${snapshot.connectionState == ConnectionState.done ? ' ${articles.length}' : ''}',
                              color: foreground,
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _IssueDetailMessage(
                      message: '관련 기사를 불러오지 못했습니다.',
                      color: muted,
                    ),
                  )
                else if (articles.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _IssueDetailMessage(
                      message: '관련 기사가 아직 없습니다.',
                      color: muted,
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 0 : 20,
                            0,
                            isDesktop ? 0 : 20,
                            28,
                          ),
                          child: Column(
                            children: [
                              for (var index = 0;
                                  index < articles.length;
                                  index++) ...[
                                _IssueDetailArticleRow(
                                  item: articles[index],
                                  foreground: foreground,
                                  muted: muted,
                                ),
                                if (index < articles.length - 1)
                                  Divider(color: border, height: 1),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IssueDetailMeta extends StatelessWidget {
  final String category;
  final String time;
  final Color muted;

  const _IssueDetailMeta(
      {required this.category, required this.time, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          category.trim().isEmpty ? '뉴스' : category.trim(),
          style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 7),
        Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: muted, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(time, style: TextStyle(color: muted, fontSize: 12)),
      ],
    );
  }
}

class _IssueDetailHeading extends StatelessWidget {
  final String title;
  final Color color;

  const _IssueDetailHeading({required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style:
            TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700),
      );
}

class _IssueDetailTimelineRow extends StatelessWidget {
  final IssueTimelineEvent event;
  final Color muted;
  final Color foreground;

  const _IssueDetailTimelineRow({
    required this.event,
    required this.muted,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _issueTimelineClockLabel(event.occurredAt),
              style: TextStyle(
                  color: muted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              event.description,
              style: TextStyle(color: foreground, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueDetailArticleRow extends StatelessWidget {
  final TrendItem item;
  final Color foreground;
  final Color muted;

  const _IssueDetailArticleRow(
      {required this.item, required this.foreground, required this.muted});

  @override
  Widget build(BuildContext context) {
    final source = _issueDisplaySource(item.source);
    final time = _issueArticleTimeLabel(
      item.published.isNotEmpty ? item.published : item.createdAt,
    );
    final hasLink = item.link.trim().isNotEmpty;
    return InkWell(
      onTap: hasLink ? () => _openIssueArticle(context, item.link) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (time != null) ...[
                        const SizedBox(width: 10),
                        Text(time,
                            style: TextStyle(color: muted, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.koreanTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueDetailMessage extends StatelessWidget {
  final String message;
  final Color color;

  const _IssueDetailMessage({required this.message, required this.color});

  @override
  Widget build(BuildContext context) => Center(
      child: Text(message, style: TextStyle(color: color, fontSize: 13)));
}

List<TrendItem> _sortedArticles(List<TrendItem> articles) {
  final sorted = [...articles];
  sorted.sort((left, right) {
    final leftTime = _parseIssueDetailTime(
        left.published.isNotEmpty ? left.published : left.createdAt);
    final rightTime = _parseIssueDetailTime(
        right.published.isNotEmpty ? right.published : right.createdAt);
    return (rightTime ?? DateTime(1970)).compareTo(leftTime ?? DateTime(1970));
  });
  return sorted;
}

String? _usableSummary(String summary, String title) {
  final value = summary.trim();
  final normalizedSummary =
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  final normalizedTitle =
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  if (normalizedSummary.length < 16 ||
      normalizedSummary == normalizedTitle ||
      normalizedTitle.contains(normalizedSummary)) return null;
  return value;
}

String _issueDisplayTitle(EditionIssue issue) {
  return issue.title.trim();
}

String _issueDisplaySource(String value) {
  final source = value.trim();
  if (source.isEmpty) return '출처 미상';
  final host = Uri.tryParse('https://$source')?.host;
  if (host == null || host.isEmpty) return source;
  return host.replaceFirst(RegExp(r'^www\.'), '');
}

DateTime? _parseIssueDetailTime(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

String _issueDetailTimeLabel(String value) {
  final date = _parseIssueDetailTime(value);
  if (date == null) return '최근 업데이트';
  final difference = DateTime.now().difference(date);
  if (!difference.isNegative && difference.inMinutes < 60)
    return '${difference.inMinutes == 0 ? 1 : difference.inMinutes}분 전';
  if (!difference.isNegative && difference.inHours < 24)
    return '${difference.inHours}시간 전';
  return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String? _issueArticleTimeLabel(String value) {
  final date = _parseIssueDetailTime(value);
  if (date == null) return null;
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  return '${date.month}월 ${date.day}일';
}

String _issueTimelineClockLabel(String value) {
  final date = _parseIssueDetailTime(value);
  if (date == null) return value.trim().isEmpty ? '--:--' : value.trim();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Future<void> _openIssueArticle(BuildContext context, String link) async {
  final uri = Uri.tryParse(link.trim());
  if (uri == null) return;
  final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('기사 원문을 열 수 없습니다.')));
  }
}
