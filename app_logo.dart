// import 'package:flutter/material.dart';

// class AppLogo extends StatelessWidget {
//   final double width;
//   final double height;
//   final bool white;
//   final String title;
//   final String subtitle;

//   const AppLogo({
//     super.key,
//     this.width = 220,
//     this.height = 60,
//     this.white = false,
//     this.title = 'CDGAI',
//     this.subtitle = 'Intern Attendance Portal',
//   });

//   @override
//   Widget build(BuildContext context) {
//     final Color primaryColor = white ? Colors.white : const Color(0xFF800000);
//     final Color secondaryColor =
//         white ? Colors.white70 : const Color(0xFF3A3A3A);

//     return SizedBox(
//       width: width,
//       height: height,
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Container(
//             width: height,
//             height: height,
//             decoration: BoxDecoration(
//               color: primaryColor,
//               borderRadius: BorderRadius.circular(14),
//             ),
//             alignment: Alignment.center,
//             child: Text(
//               'AI',
//               style: TextStyle(
//                 color: white ? Colors.black : Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 22,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(
//                     color: primaryColor,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   subtitle,
//                   style: TextStyle(
//                     color: secondaryColor,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w500,
//                   ),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final bool white;
  final String title;
  final String subtitle;

  const AppLogo({
    super.key,
    this.width = 300,
    this.height = 60,
    this.white = false,
    this.title = 'CDGAI',
    this.subtitle = 'Attendance Portal',
  });

  @override
  Widget build(BuildContext context) {
    // New Brand Color (Maroon from the new logo)
    final Color brandMaroon = const Color(0xFF8A0020);
    final Color primaryTextColor = white ? Colors.white : brandMaroon;
    final Color secondaryTextColor =
        white ? Colors.white70 : const Color(0xFF4A4A4A);

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The New Symbol
          Image.asset(
            'assets/images/portal_logo.png',
            height: height,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          // Divider
          Container(
            height: height * 0.7,
            width: 1.5,
            color: primaryTextColor.withOpacity(0.2),
          ),
          const SizedBox(width: 12),
          // Text Section
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
