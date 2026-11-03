import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'channels/channels_tab.dart';
import 'engagement/engagement_tab.dart';
import 'moderation/moderation_tab.dart';
import 'overview/overview_tab.dart';
import 'roles_access/roles_access_tab.dart';
import 'server_providers.dart';
import 'tools/tools_tab.dart';

/// The server screen with the six tabs of the server manager.
class ServerScreen extends ConsumerStatefulWidget {
  const ServerScreen({required this.guildId, super.key});

  final String guildId;

  @override
  ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 6,
    vsync: this,
  );

  static const List<String> _titles = <String>[
    'Overview',
    'Moderation',
    'Roles',
    'Channels',
    'Engagement',
    'Tools',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      ref.read(currentGuildIdProvider.notifier).set(widget.guildId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guildId = widget.guildId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _titles
              .map((String title) => Tab(text: title, height: 44))
              .toList(growable: false),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          OverviewTab(guildId: guildId),
          ModerationTab(guildId: guildId),
          RolesAccessTab(guildId: guildId),
          ChannelsTab(guildId: guildId),
          EngagementTab(guildId: guildId),
          ToolsTab(guildId: guildId),
        ],
      ),
    );
  }
}
