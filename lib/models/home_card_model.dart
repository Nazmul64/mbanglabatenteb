class HomeCardModel {
  final int id;
  final String title;
  final String? subtitle;
  final String? description;
  final String screenKey;
  final String? link;
  final String iconClass;
  final String color;
  final String? iconUrl;
  final int orderIndex;
  final bool isActive;

  HomeCardModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    required this.screenKey,
    this.link,
    this.iconClass = 'fa-solid fa-shapes',
    this.color = '#3B82F6',
    this.iconUrl,
    required this.orderIndex,
    required this.isActive,
  });

  factory HomeCardModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['id'] is int) {
      parsedId = json['id'];
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    }

    int parsedOrder = 0;
    if (json['order_index'] is int) {
      parsedOrder = json['order_index'];
    } else if (json['order_index'] != null) {
      parsedOrder = int.tryParse(json['order_index'].toString()) ?? 0;
    } else if (json['order'] is int) {
      parsedOrder = json['order'];
    } else if (json['order'] != null) {
      parsedOrder = int.tryParse(json['order'].toString()) ?? 0;
    }

    final rawStatus = json['status'];
    final bool statusActive = rawStatus == 1 ||
        rawStatus == true ||
        rawStatus == '1' ||
        rawStatus == 'active' ||
        rawStatus == null;

    return HomeCardModel(
      id: parsedId,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      screenKey: (json['screen_key'] ?? json['key'] ?? json['slug'] ?? '').toString(),
      link: json['link']?.toString(),
      iconClass: (json['icon_class'] ?? json['icon'] ?? 'fa-solid fa-shapes').toString(),
      color: (json['color'] ?? json['icon_color'] ?? '#3B82F6').toString(),
      iconUrl: json['icon_url']?.toString() ?? json['image_url']?.toString(),
      orderIndex: parsedOrder,
      isActive: statusActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'screen_key': screenKey,
      'link': link,
      'icon_class': iconClass,
      'color': color,
      'icon_url': iconUrl,
      'order_index': orderIndex,
      'status': isActive ? 1 : 0,
    };
  }
}
