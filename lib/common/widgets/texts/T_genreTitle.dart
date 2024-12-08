import 'package:book_Verse/common/widgets/texts/t_genretitle_text.dart';
import 'package:flutter/cupertino.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/constants/sizes.dart';

class TGenreTitleWithVerification extends StatelessWidget {
  const TGenreTitleWithVerification({
    super.key,
    required this.title,
    this.maxLines = 1,
    this.textColor,
    this.textAlign = TextAlign.start,
    this.genreTextSizes = TextSizes.small,
  });

  final String title;
  final int maxLines;
  final Color? textColor;
  final TextAlign textAlign;
  final TextSizes genreTextSizes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: TGenreTitleText(
            title: title,
            color: textColor,
            maxLines: maxLines,
            textAlign: textAlign,
            genreTextSizes: genreTextSizes,
          ),
        ),
        const SizedBox(width: TSizes.xs),

      ],
    );
  }
}