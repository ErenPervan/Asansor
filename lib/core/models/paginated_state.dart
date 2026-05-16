class PaginatedState<T> {
  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;

  const PaginatedState({
    required this.items,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}
