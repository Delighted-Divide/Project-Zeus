class StaticData {
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

  static const String TEST_EMAIL_DOMAIN = "example.com";

  static Map<String, List<String>> getPreGeneratedData() {
    final Map<String, List<String>> data = {};

    data['firstNames'] = [
      'Alex',
      'Jamie',
      'Jordan',
      'Taylor',
      'Morgan',
      'Casey',
      'Drew',
      'Parker',
      'Quinn',
      'Riley',
      'Sam',
      'Avery',
      'Charlie',
      'Frankie',
      'Harper',
      'Kennedy',
      'London',
      'Phoenix',
      'Remy',
      'Sage',
      'Blair',
      'Cameron',
      'Denver',
      'Ellis',
      'Finley',
      'Hayden',
      'Jules',
      'Kai',
      'Lake',
      'Marley',
      'Noah',
      'Ocean',
      'Paris',
      'Reagan',
      'Salem',
      'Tatum',
      'Utah',
      'Val',
      'Winter',
      'Yael',
    ];

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
    ];
  }

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
    ];
  }

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
    ];
  }

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
    ];
  }

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
    ];
  }

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
