import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolution_journal_card.dart';

const _months = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

class EvolutionCarousel extends StatefulWidget {
  const EvolutionCarousel({
    required this.evolutions,
    required this.onOpen,
    this.onManage,
    super.key,
  });

  final List<Evolution> evolutions;
  final ValueChanged<Evolution> onOpen;
  final void Function(EvolutionJournalAction, Evolution)? onManage;

  @override
  State<EvolutionCarousel> createState() => _EvolutionCarouselState();
}

class _EvolutionCarouselState extends State<EvolutionCarousel> {
  final _controller = PageController(viewportFraction: .94);
  String? _category;
  int? _period;
  int _index = 0;
  String? _selectedId;

  int _periodOf(Evolution evolution) {
    final date = evolution.timelineDate.toLocal();
    return date.year * 100 + date.month;
  }

  List<Evolution> _filter(List<Evolution> items) {
    final category =
        items.any((item) => item.category == _category) ? _category : null;
    final period =
        items.any((item) => _periodOf(item) == _period) ? _period : null;
    return items
        .where((item) =>
            (category == null || item.category == category) &&
            (period == null || _periodOf(item) == period))
        .toList()
      ..sort((a, b) {
        final date = b.timelineDate.compareTo(a.timelineDate);
        if (date != 0) return date;
        final created = b.createdAt.compareTo(a.createdAt);
        return created != 0 ? created : b.id.compareTo(a.id);
      });
  }

  List<Evolution> get _visible => _filter(widget.evolutions);

  @override
  void didUpdateWidget(EvolutionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItems = _filter(oldWidget.evolutions);
    final items = _visible;
    final selected = items.indexWhere((item) => item.id == _selectedId);
    _index = selected >= 0
        ? selected
        : _index.clamp(0, items.isEmpty ? 0 : items.length - 1);
    _selectedId = items.isEmpty ? null : items[_index].id;
    if (!listEquals(oldItems.map((item) => item.id).toList(),
        items.map((item) => item.id).toList())) _syncPosition();
  }

  void _syncPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
    });
  }

  void _changeFilters({String? category, int? period}) {
    setState(() {
      _category = category;
      _period = period;
      _index = 0;
      final items = _visible;
      _selectedId = items.isEmpty ? null : items.first.id;
    });
    _syncPosition();
  }

  void _goTo(int index) {
    if (!_controller.hasClients) return;
    _controller.animateToPage(index,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic);
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  String _mileage(int mileage) {
    final text = mileage.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]}.');
    return '$text km';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.evolutions
        .map((item) => item.category)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final periods = widget.evolutions.map(_periodOf).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final category = categories.contains(_category) ? _category : null;
    final period = periods.contains(_period) ? _period : null;
    final items = _visible;
    final index = _index.clamp(0, items.isEmpty ? 0 : items.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (periods.length > 1) ...[
          DropdownButtonFormField<int>(
            key: ValueKey(period),
            initialValue: period ?? 0,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Período',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Todos os meses')),
              for (final value in periods)
                DropdownMenuItem(
                    value: value,
                    child:
                        Text('${_months[value % 100 - 1]} de ${value ~/ 100}')),
            ],
            onChanged: (value) => _changeFilters(
                category: category, period: value == 0 ? null : value),
          ),
          const SizedBox(height: 12),
        ],
        if (categories.length > 1) ...[
          Wrap(spacing: 8, runSpacing: 4, children: [
            ChoiceChip(
                label: const Text('Todas'),
                selected: category == null,
                onSelected: (_) => _changeFilters(period: period)),
            for (final value in categories)
              ChoiceChip(
                label: Text(evolutionCategoryLabels[value] ?? value),
                selected: category == value,
                onSelected: (_) =>
                    _changeFilters(category: value, period: period),
              ),
          ]),
          const SizedBox(height: 12),
        ],
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Icon(Icons.filter_alt_off_outlined),
              const SizedBox(height: 10),
              const Text('Nenhuma evolução neste período e categoria.',
                  textAlign: TextAlign.center),
              TextButton(
                  onPressed: () => _changeFilters(),
                  child: const Text('Limpar filtros')),
            ]),
          )
        else ...[
          SizedBox(
            height: items
                .map((e) => evolutionJournalCardHeight(context, evolution: e))
                .reduce((a, b) => a > b ? a : b),
            child: PageView.builder(
              key: ValueKey('$category:$period'),
              controller: _controller,
              padEnds: false,
              allowImplicitScrolling: true,
              itemCount: items.length,
              onPageChanged: (value) {
                if (value >= items.length) return;
                setState(() {
                  _index = value;
                  _selectedId = items[value].id;
                });
              },
              itemBuilder: (context, position) {
                final evolution = items[position];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: EvolutionJournalCard(
                        key: ValueKey(evolution.id),
                        evolution: evolution,
                        date: _date(evolution.timelineDate),
                        mileage: evolution.mileageKm == null
                            ? null
                            : _mileage(evolution.mileageKm!),
                        onOpen: () => widget.onOpen(evolution),
                        onManage: widget.onManage == null
                            ? null
                            : (action) => widget.onManage!(action, evolution),
                      )),
                );
              },
            ),
          ),
          if (items.length > 1) const SizedBox(height: 8),
          if (items.length > 1)
            Row(children: [
              IconButton(
                  tooltip: 'Evolução anterior',
                  onPressed: index == 0 ? null : () => _goTo(index - 1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                  child: Text(
                '${index + 1} de ${items.length} ${items.length == 1 ? 'evolução' : 'evoluções'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              )),
              IconButton(
                  tooltip: 'Próxima evolução',
                  onPressed:
                      index == items.length - 1 ? null : () => _goTo(index + 1),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ]),
          if (items.length > 1)
            Text('Deslize para acompanhar a história do projeto',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    );
  }
}
