/// A class that provides static data for generating test content
class StaticData {
  // Constants for generation
  static const int NUM_USERS = 40;
  static const int MIN_FRIENDS = 10;
  static const int MAX_FRIENDS = 20;
  static const int MIN_FRIEND_REQUESTS = 5;
  static const int MAX_FRIEND_REQUESTS = 10;
  static const int NUM_GROUPS = 15;
  static const int MIN_GROUP_MEMBERS = 10;
  static const int MAX_GROUP_MEMBERS = 25;
  static const int NUM_ASSESSMENTS = 30;
  static const int MIN_SHARED_USERS = 5;
  static const int MIN_SHARED_GROUPS = 3;

  // Test user email domain - helps with filtering during cleanup
  static const String TEST_EMAIL_DOMAIN = "example.com";

  /// Pre-generate static data to avoid recreating it repeatedly
  static Map<String, List<String>> getPreGeneratedData() {
    final Map<String, List<String>> data = {};

    // First names for generating test users
    data['firstNames'] = [
      'Alex',
      'Jamie',
      'Taylor',
      'Jordan',
      'Casey',
      'Riley',
      'Morgan',
      'Avery',
      'Quinn',
      'Dakota',
      'Reese',
      'Skyler',
      'Cameron',
      'Logan',
      'Harper',
      'Kennedy',
      'Peyton',
      'Emerson',
      'Bailey',
      'Rowan',
      'Finley',
      'Blake',
      'Hayden',
      'Parker',
      'Charlie',
      'Addison',
      'Sage',
      'Jean',
      'Ariel',
      'Robin',
      'Jesse',
      'Ellis',
      'Phoenix',
      'River',
      'Remy',
      'Drew',
      'Harley',
      'Tracy',
      'Kai',
      'Jules',
      'Spencer',
      'Devon',
      'Angel',
      'Ezra',
      'Rory',
    ];

    // Last names for generating test users
    data['lastNames'] = [
      'Smith',
      'Johnson',
      'Williams',
      'Brown',
      'Jones',
      'Garcia',
      'Miller',
      'Davis',
      'Rodriguez',
      'Martinez',
      'Hernandez',
      'Lopez',
      'Wilson',
      'Anderson',
      'Thomas',
      'Taylor',
      'Moore',
      'Jackson',
      'Martin',
      'Lee',
      'Perez',
      'Thompson',
      'White',
      'Harris',
      'Sanchez',
      'Clark',
      'Ramirez',
      'Lewis',
      'Robinson',
      'Walker',
      'Young',
      'Allen',
      'King',
      'Wright',
      'Scott',
      'Torres',
      'Nguyen',
      'Hill',
      'Flores',
      'Green',
      'Adams',
      'Nelson',
      'Baker',
      'Hall',
      'Rivera',
    ];

    // Status options
    data['statusOptions'] = [
      'Learning new concepts',
      'Preparing for exam',
      'Looking for study group',
      'Taking a break',
      'Open to tutoring',
      'Need help with homework',
      'Researching',
      'Working on project',
      'Available for discussion',
      'Focusing on studies',
    ];

    // Bio templates
    data['bioTemplates'] = [
      'Student interested in %s and %s.',
      'Passionate about learning %s. Also enjoys %s in free time.',
      'Studying %s with focus on %s applications.',
      'Exploring the world of %s. Fascinated by %s.',
      '%s enthusiast with background in %s.',
      'Curious mind delving into %s and %s.',
      'Dedicated to mastering %s. Side interest in %s.',
      'Academic focus: %s. Personal interest: %s.',
      'Researcher in %s with practical experience in %s.',
      'Lifelong learner with special interest in %s and %s.',
    ];

    // Interest areas for bios
    data['interests'] = [
      'mathematics',
      'physics',
      'chemistry',
      'biology',
      'history',
      'literature',
      'art',
      'music',
      'programming',
      'economics',
      'psychology',
      'philosophy',
      'linguistics',
      'engineering',
      'architecture',
      'medicine',
      'law',
      'business',
      'sociology',
    ];

    return data;
  }

  /// Assessment titles and descriptions
  static List<Map<String, String>> getAssessmentData() {
    return [
      {
        'title': 'Algebra Basics Quiz',
        'description': 'Test your knowledge of basic algebraic concepts',
      },
      {
        'title': 'Advanced Calculus',
        'description': 'Comprehensive assessment on advanced calculus topics',
      },
      {
        'title': 'Physics Mechanics Test',
        'description': 'Assessment covering Newtonian mechanics',
      },
      {
        'title': 'Organic Chemistry Challenge',
        'description': 'Test on organic chemistry reactions and mechanisms',
      },
      {
        'title': 'Biology Cell Functions',
        'description': 'Quiz on cell structures and their functions',
      },
      // Truncated for brevity, add all assessments in the actual implementation
    ];
  }

  /// Group names and descriptions
  static List<Map<String, String>> getGroupData() {
    return [
      {
        'name': 'Math Study Group',
        'description':
            'A group for students studying mathematics at all levels',
      },
      {
        'name': 'Physics Lab Partners',
        'description': 'Collaboration group for physics laboratory experiments',
      },
      {
        'name': 'Chemistry Tutoring',
        'description': 'Group for chemistry tutoring and homework help',
      },
      // Truncated for brevity, add all groups in the actual implementation
    ];
  }

  /// Subject tags data
  static List<Map<String, String>> getSubjectTags() {
    return [
      {
        'name': 'Mathematics',
        'category': 'Subject',
        'description': 'All topics related to mathematics',
      },
      {
        'name': 'Physics',
        'category': 'Subject',
        'description':
            'Study of matter, energy, and the interaction between them',
      },
      // Truncated for brevity, add all subject tags in the actual implementation
    ];
  }

  /// Topic tags data
  static List<Map<String, String>> getTopicTags() {
    return [
      {
        'name': 'Algebra',
        'category': 'Topic',
        'description': 'Branch of mathematics dealing with symbols',
      },
      {
        'name': 'Calculus',
        'category': 'Topic',
        'description': 'Study of continuous change',
      },
      // Truncated for brevity, add all topic tags in the actual implementation
    ];
  }

  /// Skill tags data
  static List<Map<String, String>> getSkillTags() {
    return [
      {
        'name': 'Problem Solving',
        'category': 'Skill',
        'description':
            'Ability to find solutions to difficult or complex issues',
      },
      {
        'name': 'Critical Thinking',
        'category': 'Skill',
        'description': 'Objective analysis and evaluation to form a judgment',
      },
      // Truncated for brevity, add all skill tags in the actual implementation
    ];
  }

  /// Goal description templates
  static List<String> getGoalDescriptions() {
    return [
      'Complete 10 assessments in mathematics',
      'Master the fundamentals of organic chemistry',
      'Improve problem-solving skills in physics',
      'Create 5 programming projects',
      'Read and analyze 3 classic literature works',
      'Develop proficiency in data analysis',
      'Understand advanced calculus concepts',
      'Complete a research project in biology',
      'Learn the basics of machine learning',
      'Improve essay writing skills',
      'Pass the final exam with distinction',
      'Complete all assignments before deadline',
      'Develop better note-taking techniques',
      'Join a study group for collaborative learning',
      'Improve presentation skills',
    ];
  }

  /// Question types for assessments
  static List<String> getQuestionTypes() {
    return [
      'multiple-choice',
      'short-answer',
      'true-false',
      'matching',
      'fill-in-blank',
    ];
  }
}
