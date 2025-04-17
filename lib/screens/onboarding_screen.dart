import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final PageController controller;
  final VoidCallback onComplete;

  const OnboardingScreen({
    Key? key,
    required this.controller,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: widget.controller,
        children: [
          _buildOnboardingPage(
            title: 'Welcome to Your AI Assistant',
            description:
                'Your intelligent companion for creating educational assessments, analyzing documents, and more.',
            icon: Icons.smart_toy,
            backgroundColor: const Color(0xFF6A3DE8),
            isFirstPage: true,
          ),
          _buildOnboardingPage(
            title: 'Set Up Your API Key',
            description:
                'You\'ll need a Gemini API key from Google AI Studio to use all features. Set it up once and you\'re ready to go.',
            icon: Icons.vpn_key,
            backgroundColor: Colors.orange,
          ),
          _buildOnboardingPage(
            title: 'Upload PDFs for Analysis',
            description:
                'Upload your educational content and select specific pages to process.',
            icon: Icons.description,
            backgroundColor: const Color(0xFF4CAF50),
          ),
          _buildOnboardingPage(
            title: 'Generate Assessments',
            description:
                'Create customized questions with adjustable difficulty, question types, and point values.',
            icon: Icons.assignment,
            backgroundColor: const Color(0xFFFFC107),
          ),
          _buildOnboardingPage(
            title: 'Intelligent Chat',
            description:
                'Ask questions, get explanations, and receive assistance with your educational needs.',
            icon: Icons.chat,
            backgroundColor: const Color(0xFF2196F3),
            isLastPage: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage({
    required String title,
    required String description,
    required IconData icon,
    required Color backgroundColor,
    bool isFirstPage = false,
    bool isLastPage = false,
  }) {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            if (isFirstPage)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 120, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isFirstPage)
                    TextButton(
                      onPressed: () {
                        widget.controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 80),
                  Row(
                    children: List.generate(5, (index) {
                      bool isActive = false;
                      if (widget.controller.hasClients) {
                        isActive = index == widget.controller.page?.round();
                      } else {
                        isActive = index == 0;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 12 : 8,
                        height: isActive ? 12 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                        ),
                      );
                    }),
                  ),
                  TextButton(
                    onPressed: () {
                      if (isLastPage) {
                        widget.onComplete();
                      } else {
                        widget.controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLastPage ? Icons.check : Icons.arrow_forward,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
