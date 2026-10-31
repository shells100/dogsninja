class DogBreed {
  DogBreed._(this.name, this.imageUrl, this.values);

  factory DogBreed.fromJson(Map<String, dynamic> json) {
    if (json['name'] is! String || (json['name'] as String).isEmpty) {
      throw const FormatException('Missing breed name');
    }
    return DogBreed._(
      json['name'] as String,
      json['image_link'] is String ? json['image_link'] as String : null,
      Map<String, dynamic>.unmodifiable(json),
    );
  }

  final String name;
  final String? imageUrl;
  final Map<String, dynamic> values;

  num? number(String key) => values[key] is num ? values[key] as num : null;

  String range(String minKey, String maxKey, {double factor = 1}) {
    final min = number(minKey);
    final max = number(maxKey);
    if (min == null || max == null) return 'Нет данных';
    String format(num n) => (n * factor).toStringAsFixed(factor == 1 ? 0 : 1);
    return '${format(min)}–${format(max)}';
  }
}
