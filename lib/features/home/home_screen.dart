import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/bloc/auth_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VidhAI Dashboard'),
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
            : const Text('Please complete onboarding first'),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final userName = context.watch<AuthBloc>().state.name ?? 'Farmer';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Text(
            'Welcome, $userName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          // Quick action cards
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            icon: Icons.auto_awesome,
            title: 'AI Quick Action',
          ),
          _buildQuickActionCard(
            icon: Icons.agriculture,
            title: 'Crop / Plantation Support',
          ),
          _buildQuickActionCard(
            icon: Icons.bug_report,
            title: 'Pest & Disease Detection',
          ),
          _buildQuickActionCard(
            icon: Icons.science,
            title: 'AI Guidance',
          ),
          const SizedBox(height: 24),

          // Market insights
          const Text(
            'Market & Price Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.show_chart,
            title: 'Market Prices',
            subtitle: 'Current crop prices in your area',
          ),
          _buildInfoCard(
            icon: Icons.trending_up,
            title: 'Demand Forecast',
            subtitle: 'Upcoming demand trends',
          ),
          const SizedBox(height: 24),

          // Community and marketplace
          const Text(
            'Community & Marketplace',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionCard(
            icon: Icons.people,
            title: 'Community',
          ),
          _buildQuickActionCard(
            icon: Icons.store,
            title: 'Marketplace Connection',
          ),
          const SizedBox(height: 24),

          // Farm information and profile
          const Text(
            'Your Farm',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.agriculture,
            title: 'Farm Information',
            subtitle: 'Your farm details and statistics',
          ),
          _buildInfoCard(
            icon: Icons.person,
            title: 'Profile',
            subtitle: 'View and edit your profile',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _buildInfoCard({
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
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}