import '../services/api_service.dart';

class SliderModel {
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String linkUrl;
  final String buttonText;
  final int orderIndex;
  final bool status;

  SliderModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.linkUrl,
    required this.buttonText,
    required this.orderIndex,
    required this.status,
  });

  factory SliderModel.fromJson(dynamic json) {
    if (json is String) {
      return SliderModel(
        id: 0,
        title: '',
        subtitle: '',
        imageUrl: ApiService.formatImageUrl(json),
        linkUrl: '',
        buttonText: '',
        orderIndex: 0,
        status: true,
      );
    }
    final map = json as Map<String, dynamic>;
    final rawImg = (map['image_url'] ?? map['image'] ?? map['photo'] ?? map['picture'] ?? map['banner_image'])?.toString() ?? '';
    return SliderModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      imageUrl: ApiService.formatImageUrl(rawImg),
      linkUrl: map['link_url']?.toString() ?? map['link']?.toString() ?? '',
      buttonText: map['button_text']?.toString() ?? '',
      orderIndex: map['order_index'] is int ? map['order_index'] : int.tryParse(map['order_index']?.toString() ?? '0') ?? 0,
      status: map['status'] == true || map['status'] == 1 || map['status'] == '1',
    );
  }
}
