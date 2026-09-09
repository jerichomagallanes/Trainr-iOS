// Generated from the Android app's strings.xml by scripts/generate-strings.sh.
// Regenerate rather than editing: the catalog and these accessors move together.
import Foundation

// swiftlint:disable all
nonisolated enum L10n {
    static var aboutTheApp: String { String(localized: "about_the_app") }
    static var addSet: String { String(localized: "add_set") }
    static var advanced: String { String(localized: "advanced") }
    static var advancedDescription: String { String(localized: "advanced_description") }
    static var advancedLevel: String { String(localized: "advanced_level") }
    static var afternoon: String { String(localized: "afternoon") }
    static var afternoonTime: String { String(localized: "afternoon_time") }
    static var age: String { String(localized: "age") }
    static var ageLabel: String { String(localized: "age_label") }
    static var aiGeneratedRoutines: String { String(localized: "ai_generated_routines") }
    static var aiPowered: String { String(localized: "ai_powered") }
    static func aiRoutineDescription(_ p1: String, _ p2: String, _ p3: String) -> String {
        String.localizedStringWithFormat(String(localized: "ai_routine_description"), p1, p2, p3)
    }
    static var aiRoutinePreviewLabel: String { String(localized: "ai_routine_preview_label") }
    static var ankleIssuesInjury: String { String(localized: "ankle_issues_injury") }
    static var anyInjuriesOrAreas: String { String(localized: "any_injuries_or_areas") }
    static var appAboutMessage: String { String(localized: "app_about_message") }
    static var appName: String { String(localized: "app_name") }
    static func appVersionFormat(_ p1: String) -> String {
        String.localizedStringWithFormat(String(localized: "app_version_format"), p1)
    }
    static var appearance: String { String(localized: "appearance") }
    static var appearanceDark: String { String(localized: "appearance_dark") }
    static var appearanceLight: String { String(localized: "appearance_light") }
    static var appearanceSystem: String { String(localized: "appearance_system") }
    static var availableEquipment: String { String(localized: "available_equipment") }
    static var back: String { String(localized: "back") }
    static var backToProfile: String { String(localized: "back_to_profile") }
    static var backToWorkoutPlan: String { String(localized: "back_to_workout_plan") }
    static var barbellPlates: String { String(localized: "barbell_plates") }
    static var beginner: String { String(localized: "beginner") }
    static var beginnerDescription: String { String(localized: "beginner_description") }
    static var beginnerLevel: String { String(localized: "beginner_level") }
    static var bench: String { String(localized: "bench") }
    static var bmiLabel: String { String(localized: "bmi_label") }
    static var bodyweightOnly: String { String(localized: "bodyweight_only") }
    static var bodyweightOnlyLabel: String { String(localized: "bodyweight_only_label") }
    static var both: String { String(localized: "both") }
    static var bothLocation: String { String(localized: "both_location") }
    static var buildMuscle: String { String(localized: "build_muscle") }
    static var buildMuscleDescription: String { String(localized: "build_muscle_description") }
    static var buildMuscleGoal: String { String(localized: "build_muscle_goal") }
    static var cableMachine: String { String(localized: "cable_machine") }
    static var cancel: String { String(localized: "cancel") }
    static var cardio: String { String(localized: "cardio") }
    static var cardioDescription: String { String(localized: "cardio_description") }
    static var cardioEquipment: String { String(localized: "cardio_equipment") }
    static var cardioStyle: String { String(localized: "cardio_style") }
    static var close: String { String(localized: "close") }
    static var completed: String { String(localized: "completed") }
    static var createMyPlan: String { String(localized: "create_my_plan") }
    static func dayCompletedFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "day_completed_format"), p1)
    }
    static var dayCompletedMessage: String { String(localized: "day_completed_message") }
    static func daysCompletedFormat(_ p1: Int, _ p2: Int, _ p3: Int) -> String {
        String.localizedStringWithFormat(String(localized: "days_completed_format"), p1, p2, p3)
    }
    static func daysPerWeekFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "days_per_week_format"), p1)
    }
    static var deleteSet: String { String(localized: "delete_set") }
    static var deleteWeekConfirm: String { String(localized: "delete_week_confirm") }
    static var deleteWeekMessage: String { String(localized: "delete_week_message") }
    static func deleteWeekMessageTrained(_ p1: Int, _ p2: Int) -> String {
        String.localizedStringWithFormat(String(localized: "delete_week_message_trained"), p1, p2)
    }
    static func deleteWeekTitle(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "delete_week_title"), p1)
    }
    static var dropdownContentDescription: String { String(localized: "dropdown_content_description") }
    static var dumbbells: String { String(localized: "dumbbells") }
    static var durationLabel: String { String(localized: "duration_label") }
    static func durationMinutesFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "duration_minutes_format"), p1)
    }
    static var earlyMorning: String { String(localized: "early_morning") }
    static var earlyMorningTime: String { String(localized: "early_morning_time") }
    static var edit: String { String(localized: "edit") }
    static var enterYourAge: String { String(localized: "enter_your_age") }
    static var enterYourFirstName: String { String(localized: "enter_your_first_name") }
    static var equipmentLabel: String { String(localized: "equipment_label") }
    static var equipmentLabelFull: String { String(localized: "equipment_label_full") }
    static var errorEnterAge: String { String(localized: "error_enter_age") }
    static var errorEnterHeight: String { String(localized: "error_enter_height") }
    static var errorEnterName: String { String(localized: "error_enter_name") }
    static var errorEnterWeight: String { String(localized: "error_enter_weight") }
    static var evening: String { String(localized: "evening") }
    static var eveningTime: String { String(localized: "evening_time") }
    static var exerciseInProgress: String { String(localized: "exercise_in_progress") }
    static func exercisesCount(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "exercises_count"), p1)
    }
    static var experienceLabel: String { String(localized: "experience_label") }
    static var female: String { String(localized: "female") }
    static var femaleGender: String { String(localized: "female_gender") }
    static var fitnessExperience: String { String(localized: "fitness_experience") }
    static var fitnessGoalsLabel: String { String(localized: "fitness_goals_label") }
    static var flexibilityMobility: String { String(localized: "flexibility_mobility") }
    static var flexibilityMobilityDescription: String { String(localized: "flexibility_mobility_description") }
    static var flexibilityMobilityGoal: String { String(localized: "flexibility_mobility_goal") }
    static var flexibilityMobilityStyle: String { String(localized: "flexibility_mobility_style") }
    static var flexibleAnytime: String { String(localized: "flexible_anytime") }
    static var flexibleAnytimeTime: String { String(localized: "flexible_anytime_time") }
    static var flexibleSchedule: String { String(localized: "flexible_schedule") }
    static var gender: String { String(localized: "gender") }
    static var genderLabel: String { String(localized: "gender_label") }
    static var generalFitness: String { String(localized: "general_fitness") }
    static var generalFitnessDescription: String { String(localized: "general_fitness_description") }
    static var generalFitnessGoal: String { String(localized: "general_fitness_goal") }
    static var generateMyWorkoutPlan: String { String(localized: "generate_my_workout_plan") }
    static var generateNextWeek: String { String(localized: "generate_next_week") }
    static var generatingYourWorkoutRoutine: String { String(localized: "generating_your_workout_routine") }
    static var generationFailedMessage: String { String(localized: "generation_failed_message") }
    static var generationFailedOffline: String { String(localized: "generation_failed_offline") }
    static var generationFailedTitle: String { String(localized: "generation_failed_title") }
    static var generationLimitMessage: String { String(localized: "generation_limit_message") }
    static var generationLimitTitle: String { String(localized: "generation_limit_title") }
    static var getStarted: String { String(localized: "get_started") }
    static var getStronger: String { String(localized: "get_stronger") }
    static var getStrongerDescription: String { String(localized: "get_stronger_description") }
    static var getStrongerGoal: String { String(localized: "get_stronger_goal") }
    static var goalDescription: String { String(localized: "goal_description") }
    static var goalFocusBuildMuscle: String { String(localized: "goal_focus_build_muscle") }
    static var goalFocusFlexibility: String { String(localized: "goal_focus_flexibility") }
    static var goalFocusGeneralFitness: String { String(localized: "goal_focus_general_fitness") }
    static var goalFocusGetStronger: String { String(localized: "goal_focus_get_stronger") }
    static var goalFocusImproveEndurance: String { String(localized: "goal_focus_improve_endurance") }
    static var goalFocusLoseWeight: String { String(localized: "goal_focus_lose_weight") }
    static var gotIt: String { String(localized: "got_it") }
    static var gym: String { String(localized: "gym") }
    static var gymLocation: String { String(localized: "gym_location") }
    static var healthDisclaimer: String { String(localized: "health_disclaimer") }
    static var heightCm: String { String(localized: "height_cm") }
    static func heightCmFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "height_cm_format"), p1)
    }
    static var heightFtIn: String { String(localized: "height_ft_in") }
    static var heightLabel: String { String(localized: "height_label") }
    static var heightPlaceholderCm: String { String(localized: "height_placeholder_cm") }
    static var heightPlaceholderImperial: String { String(localized: "height_placeholder_imperial") }
    static var hideVideoTutorial: String { String(localized: "hide_video_tutorial") }
    static var hiit: String { String(localized: "hiit") }
    static var hiitDescription: String { String(localized: "hiit_description") }
    static var hiitStyle: String { String(localized: "hiit_style") }
    static var hipProblemsInjury: String { String(localized: "hip_problems_injury") }
    static var home: String { String(localized: "home") }
    static var homeLocation: String { String(localized: "home_location") }
    static var imperial: String { String(localized: "imperial") }
    static var improveEndurance: String { String(localized: "improve_endurance") }
    static var improveEnduranceDescription: String { String(localized: "improve_endurance_description") }
    static var improveEnduranceGoal: String { String(localized: "improve_endurance_goal") }
    static var inProgress: String { String(localized: "in_progress") }
    static var injuriesConcernsLabel: String { String(localized: "injuries_concerns_label") }
    static var intermediate: String { String(localized: "intermediate") }
    static var intermediateDescription: String { String(localized: "intermediate_description") }
    static var intermediateLevel: String { String(localized: "intermediate_level") }
    static var kettlebells: String { String(localized: "kettlebells") }
    static var kneeProblemsInjury: String { String(localized: "knee_problems_injury") }
    static var languageEnglish: String { String(localized: "language_english") }
    static var languageJapanese: String { String(localized: "language_japanese") }
    static var languageSelection: String { String(localized: "language_selection") }
    static var languageTagalog: String { String(localized: "language_tagalog") }
    static var leavePlanConfirm: String { String(localized: "leave_plan_confirm") }
    static var leavePlanMessage: String { String(localized: "leave_plan_message") }
    static var leavePlanTitle: String { String(localized: "leave_plan_title") }
    static var letsKeepYouSafe: String { String(localized: "lets_keep_you_safe") }
    static var limitationsDescription: String { String(localized: "limitations_description") }
    static var limitationsLabel: String { String(localized: "limitations_label") }
    static var locationLabel: String { String(localized: "location_label") }
    static var loseWeight: String { String(localized: "lose_weight") }
    static var loseWeightDescription: String { String(localized: "lose_weight_description") }
    static var loseWeightGoal: String { String(localized: "lose_weight_goal") }
    static var lowerBackPainInjury: String { String(localized: "lower_back_pain_injury") }
    static var mainGoalLabel: String { String(localized: "main_goal_label") }
    static var male: String { String(localized: "male") }
    static var maleGender: String { String(localized: "male_gender") }
    static var markExerciseComplete: String { String(localized: "mark_exercise_complete") }
    static var markExerciseIncomplete: String { String(localized: "mark_exercise_incomplete") }
    static var markSetComplete: String { String(localized: "mark_set_complete") }
    static var markSetIncomplete: String { String(localized: "mark_set_incomplete") }
    static var measurementsDescription: String { String(localized: "measurements_description") }
    static var measurementsLabel: String { String(localized: "measurements_label") }
    static var metric: String { String(localized: "metric") }
    static func minutes(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "minutes"), p1)
    }
    static var missed: String { String(localized: "missed") }
    static var mixedBalanced: String { String(localized: "mixed_balanced") }
    static var mixedBalancedDescription: String { String(localized: "mixed_balanced_description") }
    static var mixedBalancedStyle: String { String(localized: "mixed_balanced_style") }
    static var morning: String { String(localized: "morning") }
    static var morningTime: String { String(localized: "morning_time") }
    static var moveEarlier: String { String(localized: "move_earlier") }
    static var moveLater: String { String(localized: "move_later") }
    static var nameLabel: String { String(localized: "name_label") }
    static var neckPainInjury: String { String(localized: "neck_pain_injury") }
    static var next: String { String(localized: "next") }
    static var noPlanMessage: String { String(localized: "no_plan_message") }
    static var noPlanTitle: String { String(localized: "no_plan_title") }
    static var none: String { String(localized: "none") }
    static var noneInjury: String { String(localized: "none_injury") }
    static var noneLabel: String { String(localized: "none_label") }
    static var normalWeight: String { String(localized: "normal_weight") }
    static var notCompleted: String { String(localized: "not_completed") }
    static var notStarted: String { String(localized: "not_started") }
    static var obese: String { String(localized: "obese") }
    static func optionalLabel(_ p1: String) -> String {
        String.localizedStringWithFormat(String(localized: "optional_label"), p1)
    }
    static var other: String { String(localized: "other") }
    static var otherGender: String { String(localized: "other_gender") }
    static var others: String { String(localized: "others") }
    static var overweight: String { String(localized: "overweight") }
    static var pauseTimer: String { String(localized: "pause_timer") }
    static var personalInformation: String { String(localized: "personal_information") }
    static var personalTrainer: String { String(localized: "personal_trainer") }
    static var personalizedWorkoutPlans: String { String(localized: "personalized_workout_plans") }
    static var planOptions: String { String(localized: "plan_options") }
    static var preferredFirstName: String { String(localized: "preferred_first_name") }
    static var preferredTimeLabel: String { String(localized: "preferred_time_label") }
    static var preferredWorkoutStyle: String { String(localized: "preferred_workout_style") }
    static var preferredWorkoutTime: String { String(localized: "preferred_workout_time") }
    static var previousColumn: String { String(localized: "previous_column") }
    static var proBenefitFreshPlan: String { String(localized: "pro_benefit_fresh_plan") }
    static var proBenefitNextWeek: String { String(localized: "pro_benefit_next_week") }
    static var proBenefitRegenerate: String { String(localized: "pro_benefit_regenerate") }
    static var proBestValue: String { String(localized: "pro_best_value") }
    static var proBilledAnnually: String { String(localized: "pro_billed_annually") }
    static var proBilledMonthly: String { String(localized: "pro_billed_monthly") }
    static var proBuyLifetime: String { String(localized: "pro_buy_lifetime") }
    static var proCancelAnytime: String { String(localized: "pro_cancel_anytime") }
    static var proCompareFree: String { String(localized: "pro_compare_free") }
    static var proCompareFresh: String { String(localized: "pro_compare_fresh") }
    static var proCompareGenerated: String { String(localized: "pro_compare_generated") }
    static var proCompareHistory: String { String(localized: "pro_compare_history") }
    static var proCompareLogging: String { String(localized: "pro_compare_logging") }
    static var proCompareOne: String { String(localized: "pro_compare_one") }
    static var proComparePro: String { String(localized: "pro_compare_pro") }
    static var proCompareRepeat: String { String(localized: "pro_compare_repeat") }
    static var proCompareRewrite: String { String(localized: "pro_compare_rewrite") }
    static var proCompareTimer: String { String(localized: "pro_compare_timer") }
    static var proCompareTitle: String { String(localized: "pro_compare_title") }
    static var proCompareUnlimited: String { String(localized: "pro_compare_unlimited") }
    static var proFaqCancelA: String { String(localized: "pro_faq_cancel_a") }
    static var proFaqCancelQ: String { String(localized: "pro_faq_cancel_q") }
    static var proFaqDevicesA: String { String(localized: "pro_faq_devices_a") }
    static var proFaqDevicesQ: String { String(localized: "pro_faq_devices_q") }
    static var proFaqFreeA: String { String(localized: "pro_faq_free_a") }
    static var proFaqFreeQ: String { String(localized: "pro_faq_free_q") }
    static var proFaqHumanA: String { String(localized: "pro_faq_human_a") }
    static var proFaqHumanQ: String { String(localized: "pro_faq_human_q") }
    static var proFaqIncludesA: String { String(localized: "pro_faq_includes_a") }
    static var proFaqIncludesQ: String { String(localized: "pro_faq_includes_q") }
    static var proFaqRenewA: String { String(localized: "pro_faq_renew_a") }
    static var proFaqRenewQ: String { String(localized: "pro_faq_renew_q") }
    static var proFeatureFreshBody: String { String(localized: "pro_feature_fresh_body") }
    static var proFeatureFreshTitle: String { String(localized: "pro_feature_fresh_title") }
    static var proFeatureNextWeekBody: String { String(localized: "pro_feature_next_week_body") }
    static var proFeatureNextWeekTitle: String { String(localized: "pro_feature_next_week_title") }
    static var proFeatureRewriteBody: String { String(localized: "pro_feature_rewrite_body") }
    static var proFeatureRewriteTitle: String { String(localized: "pro_feature_rewrite_title") }
    static var proFeatureSupportBody: String { String(localized: "pro_feature_support_body") }
    static var proFeatureSupportTitle: String { String(localized: "pro_feature_support_title") }
    static var proFreeNote: String { String(localized: "pro_free_note") }
    static var proFullAccess: String { String(localized: "pro_full_access") }
    static var proHeadline: String { String(localized: "pro_headline") }
    static var proLifetime: String { String(localized: "pro_lifetime") }
    static var proMonthly: String { String(localized: "pro_monthly") }
    static var proName: String { String(localized: "pro_name") }
    static var proNotNow: String { String(localized: "pro_not_now") }
    static var proNothingToRestore: String { String(localized: "pro_nothing_to_restore") }
    static var proPayOnce: String { String(localized: "pro_pay_once") }
    static var proPrivacy: String { String(localized: "pro_privacy") }
    static var proQuestions: String { String(localized: "pro_questions") }
    static var proRenewalApple: String { String(localized: "pro_renewal_apple") }
    static var proRenewalGoogle: String { String(localized: "pro_renewal_google") }
    static var proRestore: String { String(localized: "pro_restore") }
    static var proRestored: String { String(localized: "pro_restored") }
    static func proSavePercent(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "pro_save_percent"), p1)
    }
    static var proSubscribe: String { String(localized: "pro_subscribe") }
    static func proSubscribeTo(_ p1: String) -> String {
        String.localizedStringWithFormat(String(localized: "pro_subscribe_to"), p1)
    }
    static var proSupportTrouble: String { String(localized: "pro_support_trouble") }
    static var proTerms: String { String(localized: "pro_terms") }
    static func proTrialThen(_ p1: String, _ p2: String) -> String {
        String.localizedStringWithFormat(String(localized: "pro_trial_then"), p1, p2)
    }
    static var proUnavailable: String { String(localized: "pro_unavailable") }
    static var proYearly: String { String(localized: "pro_yearly") }
    static var profileAndApp: String { String(localized: "profile_and_app") }
    static var programCardio: String { String(localized: "program_cardio") }
    static var programFlexibility: String { String(localized: "program_flexibility") }
    static var programHiit: String { String(localized: "program_hiit") }
    static func programLengthFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "program_length_format"), p1)
    }
    static var programMixed: String { String(localized: "program_mixed") }
    static var programStrength: String { String(localized: "program_strength") }
    static var pullUpBar: String { String(localized: "pull_up_bar") }
    static var regeneratePlan: String { String(localized: "regenerate_plan") }
    static var regenerateWeek: String { String(localized: "regenerate_week") }
    static var regenerateWeekConfirm: String { String(localized: "regenerate_week_confirm") }
    static func regenerateWeekMessageTrained(_ p1: Int, _ p2: Int) -> String {
        String.localizedStringWithFormat(String(localized: "regenerate_week_message_trained"), p1, p2)
    }
    static var regenerateWeekTitle: String { String(localized: "regenerate_week_title") }
    static var repeatThisWeek: String { String(localized: "repeat_this_week") }
    static var repsColumn: String { String(localized: "reps_column") }
    static var resetTimer: String { String(localized: "reset_timer") }
    static var resistanceBands: String { String(localized: "resistance_bands") }
    static var resumeTimer: String { String(localized: "resume_timer") }
    static var reviewDescription: String { String(localized: "review_description") }
    static var reviewProfileDescription: String { String(localized: "review_profile_description") }
    static var save: String { String(localized: "save") }
    static var saveProfile: String { String(localized: "save_profile") }
    static var scheduleLabel: String { String(localized: "schedule_label") }
    static var selectDaysPlaceholder: String { String(localized: "select_days_placeholder") }
    static var sessionDuration: String { String(localized: "session_duration") }
    static var setColumn: String { String(localized: "set_column") }
    static var setUpYourWorkout: String { String(localized: "set_up_your_workout") }
    static var shoulderInjuryInjury: String { String(localized: "shoulder_injury_injury") }
    static var showVideoTutorial: String { String(localized: "show_video_tutorial") }
    static var skipped: String { String(localized: "skipped") }
    static var slideToCompleteRoutine: String { String(localized: "slide_to_complete_routine") }
    static var squatRack: String { String(localized: "squat_rack") }
    static var startNextWorkout: String { String(localized: "start_next_workout") }
    static var startOver: String { String(localized: "start_over") }
    static var startTimer: String { String(localized: "start_timer") }
    static var startTodaysWorkout: String { String(localized: "start_todays_workout") }
    static var startWorkoutOver: String { String(localized: "start_workout_over") }
    static var startWorkoutOverMessage: String { String(localized: "start_workout_over_message") }
    static var startWorkoutOverTitle: String { String(localized: "start_workout_over_title") }
    static var stopTimer: String { String(localized: "stop_timer") }
    static var strengthTraining: String { String(localized: "strength_training") }
    static var strengthTrainingDescription: String { String(localized: "strength_training_description") }
    static var strengthTrainingStyle: String { String(localized: "strength_training_style") }
    static var submit: String { String(localized: "submit") }
    static var tellUsAboutYourself: String { String(localized: "tell_us_about_yourself") }
    static var timeColumn: String { String(localized: "time_column") }
    static var timerPaused: String { String(localized: "timer_paused") }
    static var trackWeeklyProgress: String { String(localized: "track_weekly_progress") }
    static var trackYourProgress: String { String(localized: "track_your_progress") }
    static var trainr: String { String(localized: "trainr") }
    static var tryAgain: String { String(localized: "try_again") }
    static var underweight: String { String(localized: "underweight") }
    static var unitCm: String { String(localized: "unit_cm") }
    static var upcoming: String { String(localized: "upcoming") }
    static var updateProfile: String { String(localized: "update_profile") }
    static func valueRangeHint(_ p1: String, _ p2: String, _ p3: String) -> String {
        String.localizedStringWithFormat(String(localized: "value_range_hint"), p1, p2, p3)
    }
    static func versionFormat(_ p1: String) -> String {
        String.localizedStringWithFormat(String(localized: "version_format"), p1)
    }
    static var viewWeeklyProgress: String { String(localized: "view_weekly_progress") }
    static func weekCompletedFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "week_completed_format"), p1)
    }
    static var weekCompletedMessage: String { String(localized: "week_completed_message") }
    static func weekNumberFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "week_number_format"), p1)
    }
    static func weekRangeFormat(_ p1: Int, _ p2: String) -> String {
        String.localizedStringWithFormat(String(localized: "week_range_format"), p1, p2)
    }
    static func weekRangeParens(_ p1: String) -> String {
        String.localizedStringWithFormat(String(localized: "week_range_parens"), p1)
    }
    static var weeklyProgress: String { String(localized: "weekly_progress") }
    static var weightColumn: String { String(localized: "weight_column") }
    static var weightColumnLbs: String { String(localized: "weight_column_lbs") }
    static var weightKg: String { String(localized: "weight_kg") }
    static func weightKgFormat(_ p1: Double) -> String {
        String.localizedStringWithFormat(String(localized: "weight_kg_format"), p1)
    }
    static var weightLabel: String { String(localized: "weight_label") }
    static var weightLbs: String { String(localized: "weight_lbs") }
    static func weightLbsFormat(_ p1: String) -> String {
        String.localizedStringWithFormat(String(localized: "weight_lbs_format"), p1)
    }
    static var weightPlaceholderKg: String { String(localized: "weight_placeholder_kg") }
    static var weightPlaceholderLbs: String { String(localized: "weight_placeholder_lbs") }
    static var weightsInLabel: String { String(localized: "weights_in_label") }
    static var weightsMarkedIn: String { String(localized: "weights_marked_in") }
    static var welcomeTo: String { String(localized: "welcome_to") }
    static var whereWillYouWorkOut: String { String(localized: "where_will_you_work_out") }
    static func workoutDaysOption(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "workout_days_option"), p1)
    }
    static var workoutDaysPerWeek: String { String(localized: "workout_days_per_week") }
    static var workoutSetupLabel: String { String(localized: "workout_setup_label") }
    static var workoutStyleLabel: String { String(localized: "workout_style_label") }
    static var wristPainInjury: String { String(localized: "wrist_pain_injury") }
    static func yearsOldFormat(_ p1: Int) -> String {
        String.localizedStringWithFormat(String(localized: "years_old_format"), p1)
    }
    static var your: String { String(localized: "your") }
    static var yourFitnessGoals: String { String(localized: "your_fitness_goals") }
    static var yourFitnessProfile: String { String(localized: "your_fitness_profile") }
    static var yourMeasurements: String { String(localized: "your_measurements") }
    static var yourWeeklyWorkoutPlan: String { String(localized: "your_weekly_workout_plan") }
}
// swiftlint:enable all
