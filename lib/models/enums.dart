// Enumerações centrais do app Prospera.

enum TxType { ingreso, gasto, inversion, deuda }

extension TxTypeX on TxType {
  String get label {
    switch (this) {
      case TxType.ingreso:
        return 'Ingreso';
      case TxType.gasto:
        return 'Gasto';
      case TxType.inversion:
        return 'Inversión';
      case TxType.deuda:
        return 'Deuda';
    }
  }

  static TxType fromString(String s) {
    return TxType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TxType.gasto,
    );
  }

  bool get isOutflow => this == TxType.gasto || this == TxType.deuda;
  bool get isInflow => this == TxType.ingreso;
}

enum TxNature { fijo, variable }

extension TxNatureX on TxNature {
  String get label => this == TxNature.fijo ? 'Fijo' : 'Variable';

  static TxNature fromString(String s) {
    return TxNature.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TxNature.variable,
    );
  }
}

enum TxStatus { pagado, pendiente }

extension TxStatusX on TxStatus {
  String get label => this == TxStatus.pagado ? 'Pagado' : 'Pendiente';

  static TxStatus fromString(String s) {
    return TxStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TxStatus.pendiente,
    );
  }
}

enum PaymentMethod {
  efectivo,
  transferencia,
  tarjetaCredito,
  tarjetaDebito,
  otro,
}

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.efectivo:
        return 'Efectivo';
      case PaymentMethod.transferencia:
        return 'Transferencia';
      case PaymentMethod.tarjetaCredito:
        return 'Tarjeta de crédito';
      case PaymentMethod.tarjetaDebito:
        return 'Tarjeta de débito';
      case PaymentMethod.otro:
        return 'Otro';
    }
  }

  static PaymentMethod fromString(String s) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PaymentMethod.efectivo,
    );
  }
}

enum Priority { alta, media, baja }

extension PriorityX on Priority {
  String get label {
    switch (this) {
      case Priority.alta:
        return 'Alta';
      case Priority.media:
        return 'Media';
      case Priority.baja:
        return 'Baja';
    }
  }

  static Priority fromString(String s) {
    return Priority.values.firstWhere(
      (e) => e.name == s,
      orElse: () => Priority.media,
    );
  }
}
