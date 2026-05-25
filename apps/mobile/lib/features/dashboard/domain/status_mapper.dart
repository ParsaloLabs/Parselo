class StatusMapper {
  static const Map<String, String> statusLabels = {
    'pending': 'Awaiting agent',
    'agent_assigned': 'Agent assigned',
    'agent_en_route_pickup': 'Agent on the way',
    'parcel_collected': 'Picked up',
    'out_for_delivery': 'On the way to drop',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
    'failed': 'Failed',
  };

  static String getLabel(String status) {
    return statusLabels[status] ?? status;
  }
}
