import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/bloc/auth_state.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('dashboard')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().logout();
            },
          ),
        ],
      ),
      body: Center(
        child: authState is AuthAuthenticated
            ? _buildDashboard(context)
            : Text(loc.completeOnboarding),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final userName =
        context.watch<AuthBloc>().state.name ?? loc.defaultUserNameFarmer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Text(
            loc.helloNamed.replaceFirst('{name}', userName),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          // Quick action cards
          Text(
            loc.quickActions,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            context,
            icon: Icons.auto_awesome,
            title: loc.aiQuickAction,
          ),
          _buildQuickActionCard(
            context,
            icon: Icons.agriculture,
            title: loc.cropSupport,
          ),
          _buildQuickActionCard(
            context,
            icon: Icons.bug_report,
            title: loc.pestDetection,
          ),
          _buildQuickActionCard(
            context,
            icon: Icons.science,
            title: loc.aiGuidance,
          ),
          const SizedBox(height: 24),

          // Market insights
          Text(
            loc.marketInsights,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            icon: Icons.show_chart,
            title: loc.marketPrices,
            subtitle: loc.t('current_crop_prices'),
          ),
          _buildInfoCard(
            context,
            icon: Icons.trending_up,
            title: loc.demandForecast,
            subtitle: loc.t('demand_trends'),
          ),
          const SizedBox(height: 24),

          // Community and marketplace
          Text(
            loc.t('community_and_marketplace'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            context,
            icon: Icons.people,
            title: loc.community,
          ),
          _buildQuickActionCard(
            context,
            icon: Icons.store,
            title: loc.marketplace,
          ),
          const SizedBox(height: 24),

          // Farm information and profile
          Text(
            loc.yourFarm,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            icon: Icons.agriculture,
            title: loc.farmInfo,
            subtitle: loc.t('farm_details_stats'),
          ),
          _buildInfoCard(
            context,
            icon: Icons.person,
            title: loc.profile,
            subtitle: loc.t('view_edit_profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title),
        trailing:
            Icon(directionalIcon(context, Icons.arrow_forward_ios), size: 16),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing:
            Icon(directionalIcon(context, Icons.arrow_forward_ios), size: 16),
      ),
    );
  }
}
