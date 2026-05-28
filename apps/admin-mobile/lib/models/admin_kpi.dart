class AdminKpis {
  final int ordersToday;
  final int activeOrders;
  final int agentsOnline;
  final int revenueTodayPaise;
  final int failedCount;
  final int refundRequestedCount;
  final int registeredUsers;
  final int totalAgents;

  AdminKpis({
    required this.ordersToday,
    required this.activeOrders,
    required this.agentsOnline,
    required this.revenueTodayPaise,
    required this.failedCount,
    required this.refundRequestedCount,
    required this.registeredUsers,
    required this.totalAgents,
  });

  factory AdminKpis.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return AdminKpis(
      ordersToday: parseInt(json['orders_today']),
      activeOrders: parseInt(json['active_orders']),
      agentsOnline: parseInt(json['agents_online']),
      revenueTodayPaise: parseInt(json['revenue_today_paise']),
      failedCount: parseInt(json['failed_count']),
      refundRequestedCount: parseInt(json['refund_requested_count']),
      registeredUsers: parseInt(json['registered_users']),
      totalAgents: parseInt(json['total_agents']),
    );
  }
}
