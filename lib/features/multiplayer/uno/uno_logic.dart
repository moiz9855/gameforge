import 'dart:math';

enum UnoColor { red, yellow, green, blue, wild }
enum UnoType { number, skip, reverse, drawTwo, wild, wildDrawFour }

class UnoCard {
  final UnoColor color;
  final UnoType type;
  final int? number; // Only for UnoType.number

  const UnoCard({
    required this.color,
    required this.type,
    this.number,
  });

  String get label {
    switch (type) {
      case UnoType.number: return number!.toString();
      case UnoType.skip: return "⏭️";
      case UnoType.reverse: return "🔄";
      case UnoType.drawTwo: return "+2";
      case UnoType.wild: return "🌈";
      case UnoType.wildDrawFour: return "+4🌈";
    }
  }

  Map<String, dynamic> toJson() => {
        'color': color.index,
        'type': type.index,
        'number': number,
      };

  factory UnoCard.fromJson(Map<String, dynamic> json) => UnoCard(
        color: UnoColor.values[json['color'] as int],
        type: UnoType.values[json['type'] as int],
        number: json['number'] as int?,
      );

  bool isValidPlay(UnoCard topCard, UnoColor? selectedWildColor) {
    if (color == UnoColor.wild) return true; // Wilds are always valid
    
    // If top card is wild, compare with the chosen wild color
    final targetColor = topCard.color == UnoColor.wild ? (selectedWildColor ?? UnoColor.wild) : topCard.color;
    if (color == targetColor) return true;
    
    if (type == topCard.type && type != UnoType.number) return true;
    if (type == UnoType.number && topCard.type == UnoType.number && number == topCard.number) return true;
    
    return false;
  }
}

List<UnoCard> generateUnoDeck() {
  final deck = <UnoCard>[];

  // Number cards for all 4 colors
  for (var color in [UnoColor.red, UnoColor.yellow, UnoColor.green, UnoColor.blue]) {
    deck.add(UnoCard(color: color, type: UnoType.number, number: 0));
    for (int i = 1; i <= 9; i++) {
      deck.add(UnoCard(color: color, type: UnoType.number, number: i));
      deck.add(UnoCard(color: color, type: UnoType.number, number: i));
    }
    // Action cards: 2 of each per color
    for (int i = 0; i < 2; i++) {
      deck.add(UnoCard(color: color, type: UnoType.skip));
      deck.add(UnoCard(color: color, type: UnoType.reverse));
      deck.add(UnoCard(color: color, type: UnoType.drawTwo));
    }
  }

  // Wild cards: 4 of each
  for (int i = 0; i < 4; i++) {
    deck.add(const UnoCard(color: UnoColor.wild, type: UnoType.wild));
    deck.add(const UnoCard(color: UnoColor.wild, type: UnoType.wildDrawFour));
  }

  return deck..shuffle(Random());
}
