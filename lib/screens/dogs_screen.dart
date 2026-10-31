import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/dog_breed.dart';
import '../network/dogs_api.dart';

const ratingLabels = {
  'energy': 'Энергичность',
  'barking': 'Склонность к лаю',
  'trainability': 'Обучаемость',
  'shedding': 'Линька',
  'good_with_children': 'С детьми',
  'good_with_other_dogs': 'С другими собаками',
  'good_with_strangers': 'С незнакомцами',
  'grooming': 'Потребность в уходе',
  'drooling': 'Слюноотделение',
  'coat_length': 'Длина шерсти',
  'playfulness': 'Игривость',
  'protectiveness': 'Охранный инстинкт',
};

class DogsScreen extends StatefulWidget {
  const DogsScreen({super.key, required this.api});

  final DogsApi api;

  @override
  State<DogsScreen> createState() => _DogsScreenState();
}

class _DogsScreenState extends State<DogsScreen> {
  final _name = TextEditingController();
  final _ratings = <String, int?>{
    'energy': null,
    'barking': null,
    'trainability': null,
  };
  List<DogBreed> _breeds = [];
  Map<String, dynamic> _activeFilters = {};
  Map<String, dynamic> _lastFilters = {};
  int _offset = 0;
  int _lastOffset = 0;
  int _requestId = 0;
  bool _loading = false;
  bool _searched = false;
  String? _error;
  CancelToken? _cancel;

  @override
  void dispose() {
    _cancel?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _search() {
    final filters = <String, dynamic>{
      if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
      for (final entry in _ratings.entries)
        if (entry.value != null) entry.key: entry.value,
    };
    if (filters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введи название породы или выбери характеристику.'),
        ),
      );
      return;
    }
    _load(filters, 0);
  }

  Future<void> _load(Map<String, dynamic> filters, int offset) async {
    final id = ++_requestId;
    _cancel?.cancel();
    final cancel = CancelToken();
    _cancel = cancel;
    setState(() {
      _lastFilters = Map.of(filters);
      _lastOffset = offset;
      _loading = true;
      _searched = true;
      _error = null;
      _breeds = [];
    });
    try {
      final breeds = await widget.api.search(
        filters,
        offset: offset,
        cancelToken: cancel,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _breeds = breeds;
        _offset = offset;
        _activeFilters = Map.of(filters);
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      if (error is DioException && CancelToken.isCancel(error)) return;
      setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Найди свою породу',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Узнай больше о характере, размерах и привычках собак.',
                  ),
                  const SizedBox(height: 26),
                  _searchForm(),
                  const SizedBox(height: 28),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 18),
                            Text('Ищем породы…'),
                          ],
                        ),
                      ),
                    )
                  else if (_error != null)
                    _message(
                      Icons.wifi_off,
                      _error!,
                      action: TextButton.icon(
                        onPressed: () => _load(_lastFilters, _lastOffset),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    )
                  else if (!_searched)
                    _message(
                      Icons.travel_explore,
                      'Начни с названия или характеристик породы.',
                    )
                  else ...[
                    Text(
                      'Результаты поиска',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeFilters.entries
                          .map(
                            (e) =>
                                '${ratingLabels[e.key] ?? 'Название'}: ${e.value}',
                          )
                          .join(' · '),
                    ),
                    const SizedBox(height: 18),
                    if (_breeds.isEmpty)
                      _message(
                        Icons.search_off,
                        'Породы не найдены. Попробуй другое название или фильтры.',
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 850
                              ? 3
                              : constraints.maxWidth >= 540
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 16) /
                              columns;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final breed in _breeds)
                                SizedBox(
                                  width: width,
                                  child: _breedCard(breed),
                                ),
                            ],
                          );
                        },
                      ),
                    if (_offset > 0 || _breeds.length == 20) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Предыдущая страница',
                            onPressed: _offset == 0
                                ? null
                                : () => _load(_activeFilters, _offset - 20),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Страница ${_offset ~/ 20 + 1}'),
                          IconButton(
                            tooltip: 'Следующая страница',
                            onPressed: _breeds.length < 20
                                ? null
                                : () => _load(_activeFilters, _offset + 20),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 28),
                  const Divider(),
                  const Text(
                    'Данные: API Ninjas · Dogs API. Названия пород в API — на английском языке.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchForm() {
    return Card(
      color: const Color(0xFFEAF0E9),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'Название породы',
                hintText: 'Например, husky или retriever',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 650
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final key in _ratings.keys)
                      SizedBox(
                        width: width,
                        child: DropdownButtonFormField<int>(
                          initialValue: _ratings[key] ?? 0,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: ratingLabels[key],
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 0,
                              child: Text('Любая'),
                            ),
                            for (var i = 1; i <= 5; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('$i из 5'),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _ratings[key] = value == 0 ? null : value,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              '1 — низкая, 5 — высокая. Все выбранные условия применяются одновременно.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Найти породы'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF245C46)),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      ),
    );
  }

  Widget _breedCard(DogBreed breed) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showDetails(breed),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(breed, 180),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    breed.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Продолжительность жизни: ${breed.range('min_life_expectancy', 'max_life_expectancy')} лет',
                  ),
                  const SizedBox(height: 10),
                  for (final key in ['energy', 'trainability', 'barking'])
                    _rating(breed, key),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Text(
                        'Подробнее',
                        style: TextStyle(
                          color: Color(0xFF245C46),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(DogBreed breed, double height) {
    final uri = Uri.tryParse(breed.imageUrl ?? '');
    Widget fallback() => Container(
      height: height,
      color: const Color(0xFFEAF0E9),
      alignment: Alignment.center,
      child: const Icon(Icons.pets, size: 56, color: Color(0xFF245C46)),
    );
    if (uri == null || uri.scheme != 'https') return fallback();
    return Image.network(
      uri.toString(),
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      semanticLabel: breed.name,
      errorBuilder: (_, error, stack) => fallback(),
    );
  }

  Widget _rating(DogBreed breed, String key) {
    final value = breed.number(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(ratingLabels[key]!)),
          Text(
            value == null ? 'Нет данных' : '${value.toInt()} / 5',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showDetails(DogBreed breed) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          breed.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                _photo(breed, 240),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Продолжительность жизни: ${breed.range('min_life_expectancy', 'max_life_expectancy')} лет',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Рост кобеля: ${breed.range('min_height_male', 'max_height_male', factor: 2.54)} см',
                      ),
                      Text(
                        'Рост суки: ${breed.range('min_height_female', 'max_height_female', factor: 2.54)} см',
                      ),
                      Text(
                        'Вес кобеля: ${breed.range('min_weight_male', 'max_weight_male', factor: 0.45359237)} кг',
                      ),
                      Text(
                        'Вес суки: ${breed.range('min_weight_female', 'max_weight_female', factor: 0.45359237)} кг',
                      ),
                      const Divider(height: 28),
                      for (final key in ratingLabels.keys) _rating(breed, key),
                      const SizedBox(height: 12),
                      const Text(
                        'Оценки: от 1 до 5. Высокая оценка означает большую выраженность характеристики.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
