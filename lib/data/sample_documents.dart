import '../models/cover_letter_data.dart';
import '../models/proposal_data.dart';
import '../models/resume_data.dart';

/// Realistic placeholder content used to render a fully filled-in preview
/// of a template before the user commits to it — otherwise the template
/// grid's tiny mockup is the only clue to what a finished document looks
/// like, which isn't enough to decide.
ResumeData sampleResumeData() => ResumeData(
      personalInfo: PersonalInfo(
        fullName: 'Alexandra Bennett',
        jobTitle: 'Senior Product Designer',
        email: 'alexandra.bennett@example.com',
        phone: '+1 (555) 234-8890',
        location: 'Austin, TX',
        summary: 'Product designer with 8+ years of experience leading end-to-end design '
            'for B2B SaaS platforms. Skilled in translating complex workflows into '
            'intuitive, accessible interfaces and partnering closely with engineering '
            'and product teams to ship high-impact features.',
      ),
      experience: [
        ExperienceEntry(
          role: 'Senior Product Designer',
          company: 'Northwind Analytics',
          startDate: 'Jan 2021',
          endDate: 'Present',
          description: 'Led design for the core reporting dashboard used by 40k+ monthly users.\n'
              'Partnered with engineering to ship a redesigned onboarding flow, cutting drop-off by 22%.\n'
              'Mentored 3 junior designers and established the team\'s first design system.',
        ),
        ExperienceEntry(
          role: 'Product Designer',
          company: 'Fieldstone Software',
          startDate: 'Jun 2017',
          endDate: 'Dec 2020',
          description: 'Designed and shipped 12+ features across web and mobile for a logistics platform.\n'
              'Ran user research sessions that directly informed the redesign of the scheduling module.',
        ),
      ],
      education: [
        EducationEntry(
          degree: 'B.A. in Human-Computer Interaction',
          school: 'University of Texas at Austin',
          startDate: '2013',
          endDate: '2017',
        ),
      ],
      skills: [
        'Figma',
        'Design Systems',
        'User Research',
        'Prototyping',
        'Accessibility',
        'Cross-functional Leadership',
      ],
    );

CoverLetterData sampleCoverLetterData() => CoverLetterData(
      fullName: 'Alexandra Bennett',
      email: 'alexandra.bennett@example.com',
      phone: '+1 (555) 234-8890',
      address: 'Austin, TX',
      recipientName: 'Morgan Reyes',
      recipientTitle: 'Hiring Manager',
      companyName: 'Brightline Health',
      companyAddress: '400 Market Street, San Francisco, CA',
      date: 'July 25, 2026',
      jobTitle: 'Senior Product Designer',
      salutation: 'Dear Morgan,',
      body: 'I\'m excited to apply for the Senior Product Designer role at Brightline Health. '
          'Your team\'s work on making healthcare scheduling more accessible is exactly the kind '
          'of problem I love solving.\n\n'
          'In my current role at Northwind Analytics, I led the redesign of our core reporting '
          'dashboard, partnering closely with engineering to ship a new onboarding flow that cut '
          'drop-off by 22%. I bring the same collaborative, research-driven approach to every project.\n\n'
          'I\'d welcome the chance to bring this experience to your team and would love to talk further.',
      closing: 'Sincerely,',
    );

ProposalData sampleProposalData() => ProposalData(
      title: 'Website Redesign Proposal',
      senderName: 'Alexandra Bennett',
      senderCompany: 'Bennett Design Studio',
      senderEmail: 'alexandra@bennettdesign.com',
      senderPhone: '+1 (555) 234-8890',
      clientName: 'Morgan Reyes',
      clientCompany: 'Brightline Health',
      date: 'July 25, 2026',
      overview: 'This proposal outlines a full redesign of Brightline Health\'s marketing website, '
          'focused on improving conversion for new-patient signups and making the site easier to '
          'maintain for your internal team.',
      scopeOfWork: 'Discovery workshop and stakeholder interviews\n'
          'Information architecture and wireframes\n'
          'Visual design for 12 core pages\n'
          'Developer handoff and QA support',
      timeline: 'Weeks 1-2: Discovery\n'
          'Weeks 3-5: Wireframes and visual design\n'
          'Weeks 6-7: Development handoff\n'
          'Week 8: Launch',
      pricing: 'Discovery: \$2,000\n'
          'Design: \$6,500\n'
          'Development support: \$1,500\n'
          'Total: \$10,000',
      termsAndConditions: '50% deposit due at kickoff, remainder due at launch. Includes 2 rounds '
          'of revisions per phase.',
    );
