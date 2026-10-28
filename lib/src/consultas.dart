class ConsultaInput {
  const ConsultaInput({required this.id, required this.label});

  final String id;
  final String label;

  factory ConsultaInput.fromJson(Map<String, dynamic> json) {
    return ConsultaInput(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class ConsultaProduct {
  const ConsultaProduct({
    required this.slug,
    required this.title,
    required this.summary,
    required this.cents,
    required this.inputs,
    required this.bullets,
  });

  final String slug;
  final String title;
  final String summary;
  final int cents;
  final List<ConsultaInput> inputs;
  final List<String> bullets;

  factory ConsultaProduct.fromJson(Map<String, dynamic> json) {
    final inputs = json['inputs'];
    final bullets = json['bullets'];
    return ConsultaProduct(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      cents: (json['cents'] as num?)?.toInt() ?? 0,
      inputs: [
        if (inputs is List)
          for (final item in inputs)
            if (item is Map<String, dynamic>) ConsultaInput.fromJson(item),
      ],
      bullets: [if (bullets is List) for (final item in bullets) item.toString()],
    );
  }
}

class ConsultaRecord {
  const ConsultaRecord({
    required this.id,
    required this.slug,
    required this.title,
    required this.searchType,
    required this.document,
    required this.amountCents,
    required this.status,
    required this.error,
    required this.createdAt,
    this.result,
  });

  final int id;
  final String slug;
  final String title;
  final String searchType;
  final String document;
  final int amountCents;
  final String status;
  final String error;
  final int createdAt;
  final Object? result;

  bool get done => status == 'concluida';
  bool get waitingPayment => status == 'aguardando';

  String get statusLabel => switch (status) {
    'concluida' => 'Concluída',
    'paga' => 'Paga',
    'consultando' => 'Buscando',
    'falha' => 'Não concluída',
    'aguardando' => 'Aguardando pagamento',
    _ => status,
  };

  factory ConsultaRecord.fromJson(Map<String, dynamic> json) {
    return ConsultaRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      searchType: json['search_type'] as String? ?? '',
      document: json['document'] as String? ?? '',
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      error: json['error'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      result: json['result'],
    );
  }
}

class ConsultaBoard {
  const ConsultaBoard({required this.provider, required this.products, required this.history});

  final bool provider;
  final List<ConsultaProduct> products;
  final List<ConsultaRecord> history;

  factory ConsultaBoard.fromJson(Map<String, dynamic> json) {
    final products = json['products'];
    final history = json['history'];
    return ConsultaBoard(
      provider: json['provider'] == true,
      products: [
        if (products is List)
          for (final item in products)
            if (item is Map<String, dynamic>) ConsultaProduct.fromJson(item),
      ],
      history: [
        if (history is List)
          for (final item in history)
            if (item is Map<String, dynamic>) ConsultaRecord.fromJson(item),
      ],
    );
  }
}
