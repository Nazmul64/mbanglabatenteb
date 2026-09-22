class HomeCardModel {
  final int id;
  final String title;
  final String? subtitle;
  final String? description;
  final String screenKey;
  final String? link;
  final String mediaType;
  final String iconClass;
  final String color;
  final String iconColor;
  final String? iconUrl;
  final String? imageUrl;
  final String? lottieUrl;
  final int orderIndex;
  final bool isActive;

  HomeCardModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    required this.screenKey,
    this.link,
    this.mediaType = 'image',
    this.iconClass = 'fa-solid fa-shapes',
    this.color = '#3B82F6',
    this.iconColor = '#3B82F6',
    this.iconUrl,
    this.imageUrl,
    this.lottieUrl,
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

    final mediaType = (json['media_type'] ?? 'image').toString();
    final img = json['image_url']?.toString() ?? json['image']?.toString();
    final lottie = json['lottie_url']?.toString() ?? json['lottie']?.toString();
    final icon = json['icon_url']?.toString();

    return HomeCardModel(
      id: parsedId,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      screenKey: (json['screen_key'] ?? json['key'] ?? json['slug'] ?? '').toString(),
      link: json['link']?.toString(),
      mediaType: mediaType,
      iconClass: (json['icon_class'] ?? json['icon'] ?? 'fa-solid fa-shapes').toString(),
      color: (json['color'] ?? '#3B82F6').toString(),
      iconColor: (json['icon_color'] ?? json['color'] ?? '#3B82F6').toString(),
      iconUrl: icon ?? img,
      imageUrl: img,
      lottieUrl: lottie,
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
      'media_type': mediaType,
      'icon_class': iconClass,
      'color': color,
      'icon_color': iconColor,
      'icon_url': iconUrl,
      'image_url': imageUrl,
      'lottie_url': lottieUrl,
      'order_index': orderIndex,
      'status': isActive ? 1 : 0,
    };
  }
}
