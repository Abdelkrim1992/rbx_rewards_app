import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RbxAppHeader extends StatelessWidget {
  final ValueChanged<int>? onNavTap;

  const RbxAppHeader({super.key, this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // RBX Logo cube
              Image.network(
                AppAssets.rbxLogo,
                width: 50,
                height: 50,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.gamepad, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RBX',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF131326),
                      letterSpacing: -0.6,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'Spin & Earn',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.purple,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: onNavTap == null ? null : () => onNavTap!(3),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.purple, width: 1.5),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  )
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  AppAssets.profileAvatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person, color: AppColors.purple),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
