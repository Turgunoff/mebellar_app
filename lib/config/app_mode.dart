enum AppMode {
  customer,
  seller;

  static AppMode fromName(String? name) {
    return switch (name) {
      'seller' => AppMode.seller,
      _ => AppMode.customer,
    };
  }
}
