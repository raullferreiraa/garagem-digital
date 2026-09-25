import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/location/brazil_city.dart';

const _states = <String, String>{
  'AC': 'Acre',
  'AL': 'Alagoas',
  'AP': 'Amapá',
  'AM': 'Amazonas',
  'BA': 'Bahia',
  'CE': 'Ceará',
  'DF': 'Distrito Federal',
  'ES': 'Espírito Santo',
  'GO': 'Goiás',
  'MA': 'Maranhão',
  'MT': 'Mato Grosso',
  'MS': 'Mato Grosso do Sul',
  'MG': 'Minas Gerais',
  'PA': 'Pará',
  'PB': 'Paraíba',
  'PR': 'Paraná',
  'PE': 'Pernambuco',
  'PI': 'Piauí',
  'RJ': 'Rio de Janeiro',
  'RN': 'Rio Grande do Norte',
  'RS': 'Rio Grande do Sul',
  'RO': 'Rondônia',
  'RR': 'Roraima',
  'SC': 'Santa Catarina',
  'SP': 'São Paulo',
  'SE': 'Sergipe',
  'TO': 'Tocantins',
};

final class BrazilCityField extends StatefulWidget {
  const BrazilCityField({
    required this.cityController,
    required this.stateController,
    this.label = 'Cidade e estado',
    this.enabled = true,
    super.key,
  });

  final TextEditingController cityController;
  final TextEditingController stateController;
  final String label;
  final bool enabled;

  @override
  State<BrazilCityField> createState() => _BrazilCityFieldState();
}

class _BrazilCityFieldState extends State<BrazilCityField> {
  late final TextEditingController _display;

  @override
  void initState() {
    super.initState();
    _display = TextEditingController();
    widget.cityController.addListener(_sync);
    widget.stateController.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(covariant BrazilCityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cityController != widget.cityController ||
        oldWidget.stateController != widget.stateController) {
      oldWidget.cityController.removeListener(_sync);
      oldWidget.stateController.removeListener(_sync);
      widget.cityController.addListener(_sync);
      widget.stateController.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    final parts = [widget.cityController.text, widget.stateController.text]
        .where((value) => value.trim().isNotEmpty);
    final text = parts.join(' - ');
    if (_display.text != text) _display.text = text;
  }

  Future<void> _choose() async {
    final state = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('Selecione o estado',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: ListView(
                  children: _states.entries
                      .map((entry) => ListTile(
                            title: Text(entry.value),
                            trailing: Text(entry.key),
                            selected: widget.stateController.text == entry.key,
                            onTap: () => Navigator.pop(context, entry.key),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (state == null || !mounted) return;
    try {
      final cities = await BrazilCities.load();
      if (!mounted) return;
      final city = await showSearch<BrazilCity?>(
        context: context,
        delegate: _BrazilCitySearch(cities, state),
      );
      if (city == null || !mounted) return;
      widget.cityController.text = city.name;
      widget.stateController.text = city.state;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Não foi possível abrir a lista de cidades. Tente novamente.'),
      ));
    }
  }

  @override
  void dispose() {
    widget.cityController.removeListener(_sync);
    widget.stateController.removeListener(_sync);
    _display.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _display,
        builder: (context, value, _) => TextField(
          controller: _display,
          readOnly: true,
          enabled: widget.enabled,
          onTap: _choose,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Selecionar estado e cidade',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: widget.enabled && value.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Limpar cidade',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      widget.cityController.clear();
                      widget.stateController.clear();
                    },
                  )
                : widget.enabled
                    ? const Icon(Icons.search)
                    : null,
          ),
        ),
      );
}

class _BrazilCitySearch extends SearchDelegate<BrazilCity?> {
  _BrazilCitySearch(this.cities, this.state)
      : super(searchFieldLabel: 'Buscar cidade em $state');

  final List<BrazilCity> cities;
  final String state;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Limpar busca',
            icon: const Icon(Icons.close),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    if (query.trim().length < 2) {
      return const Center(
          child: Text('Digite pelo menos 2 letras para buscar.'));
    }
    final matches = BrazilCities.search(cities, query, state: state);
    if (matches.isEmpty) {
      return const Center(child: Text('Nenhuma cidade encontrada.'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final city = matches[index];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(city.name),
          trailing: Text(city.state),
          onTap: () => close(context, city),
        );
      },
    );
  }
}
