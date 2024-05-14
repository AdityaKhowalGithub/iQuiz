import SwiftUI

// Struct for each quiz topic
struct QuizTopic: Identifiable, Decodable {
    var id = UUID()
    var title: String
    var description: String
    var iconName: String // No default value here to avoid redundant data
    var questions: [Question]

    enum CodingKeys: String, CodingKey {
        case title
        case description = "desc"
        case iconName
        case questions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        questions = try container.decode([Question].self, forKey: .questions)
        iconName = (try? container.decode(String.self, forKey: .iconName)) ?? "questionmark.circle" // Provide a default value
    }
}

// Struct for each question
struct Question: Identifiable, Decodable {
    var id = UUID()
    var text: String
    var correctAnswer: String
    var answers: [String]

    enum CodingKeys: String, CodingKey {
        case text
        case correctAnswer = "answer"
        case answers
    }

    // Computed property to get the correct answer as an Int
    var correctAnswerIndex: Int? {
        return Int(correctAnswer)
    }
}

// Main view of the application
struct ContentView: View {
    @State private var quizTopics: [QuizTopic] = []
    @State private var showingSettings = false
    @State private var selectedQuiz: QuizTopic? = nil
    @State private var isRefreshing = false
    @State private var timer: Timer? = nil
    @AppStorage("sourceURL") private var sourceURL = "http://tednewardsandbox.site44.com/questions.json"
    @AppStorage("refreshInterval") private var refreshInterval = 60

    var body: some View {
        NavigationView {
            List(quizTopics) { topic in
                HStack {
                    Image(systemName: topic.iconName)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(topic.title)
                            .font(.headline)
                        Text(topic.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .onTapGesture {
                    selectedQuiz = topic
                }
            }
            .navigationTitle("iQuiz")
            .toolbar {
                Button("Settings") {
                    showingSettings = true
                }
            }
            .onAppear {
                loadQuizzes()
                startTimer()
            }
            .sheet(item: $selectedQuiz) { quiz in
                QuestionView(quiz: quiz)
            }
            .refreshable {
                loadQuizzes()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(loadQuizzes: loadQuizzes)
        }
    }

    func loadQuizzes() {
        guard let url = URL(string: sourceURL) else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                return
            }

            guard let data = data else {
                print("No data returned")
                return
            }

            do {
                var decodedResponse = try JSONDecoder().decode([QuizTopic].self, from: data)
                // Assign SF Symbols to each quiz topic based on the title
                for index in decodedResponse.indices {
                    switch decodedResponse[index].title {
                    case "Mathematics":
                        decodedResponse[index].iconName = "function"
                    case "Science!":
                        decodedResponse[index].iconName = "leaf.arrow.circlepath"
                    case "Marvel Super Heroes":
                        decodedResponse[index].iconName = "star.circle"
                    default:
                        decodedResponse[index].iconName = "questionmark.circle"
                    }
                }
                DispatchQueue.main.async {
                    self.quizTopics = decodedResponse
                    self.isRefreshing = false
                }
            } catch {
                print("Error decoding data: \(error)")
            }
        }.resume()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval), repeats: true) { _ in
            loadQuizzes()
        }
    }
}

struct QuestionView: View {
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: Int? = nil
    @State private var showingAnswer = false
    @State private var showingFinished = false
    @State private var score = 0

    var quiz: QuizTopic

    var body: some View {
        VStack {
            Text(quiz.questions[currentQuestionIndex].text)
                .font(.largeTitle)
            ForEach(quiz.questions[currentQuestionIndex].answers.indices, id: \.self) { index in
                Button(action: {
                    selectedAnswer = index
                    showingAnswer = true
                }) {
                    Text(quiz.questions[currentQuestionIndex].answers[index])
                        .padding()
                        .background(selectedAnswer == index ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.vertical, 5)
            }
            Button("Submit") {
                showingAnswer = true
            }
        }
        .padding()
        .sheet(isPresented: $showingAnswer) {
            AnswerView(
                quiz: quiz,
                currentQuestionIndex: $currentQuestionIndex,
                selectedAnswer: $selectedAnswer,
                showingAnswer: $showingAnswer,
                showingFinished: $showingFinished,
                score: $score
            )
        }
        .fullScreenCover(isPresented: $showingFinished) {
            FinishedView(score: score, total: quiz.questions.count)
        }
        .gesture(DragGesture()
            .onEnded { value in
                if value.translation.width > 0 {
                    showingAnswer = true
                } else if value.translation.width < 0 {
                    showingFinished = true
                }
            }
        )
    }
}

struct AnswerView: View {
    var quiz: QuizTopic
    @Binding var currentQuestionIndex: Int
    @Binding var selectedAnswer: Int?
    @Binding var showingAnswer: Bool
    @Binding var showingFinished: Bool
    @Binding var score: Int

    var body: some View {
        VStack {
            Text(quiz.questions[currentQuestionIndex].text)
                .font(.largeTitle)
            Text("Your answer: \(quiz.questions[currentQuestionIndex].answers[selectedAnswer ?? 0])")
            if let correctAnswerIndex = quiz.questions[currentQuestionIndex].correctAnswerIndex {
                Text("Correct answer: \(quiz.questions[currentQuestionIndex].answers[correctAnswerIndex])")
                if selectedAnswer == correctAnswerIndex {
                    Text("Correct!")
                        .foregroundColor(.green)
                } else {
                    Text("Incorrect!")
                        .foregroundColor(.red)
                }
            }
            Button("Next") {
                handleNext()
            }
        }
        .padding()
        .gesture(DragGesture()
            .onEnded { value in
                if value.translation.width > 0 {
                    handleNext()
                } else if value.translation.width < 0 {
                    showingFinished = true
                }
            }
        )
    }
    
    func handleNext() {
        if let correctAnswerIndex = quiz.questions[currentQuestionIndex].correctAnswerIndex {
            if selectedAnswer == correctAnswerIndex {
                score += 1
            }
        }
        if currentQuestionIndex < quiz.questions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            showingAnswer = false
        } else {
            showingFinished = true
        }
    }
}

struct FinishedView: View {
    var score: Int
    var total: Int
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Finished!")
                .font(.largeTitle)
            Text("Your score: \(score) out of \(total)")
            Button("Back to Quiz List") {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding()
    }
}

struct SettingsView: View {
    @AppStorage("sourceURL") private var sourceURL = "http://tednewardsandbox.site44.com/questions.json"
    @AppStorage("refreshInterval") private var refreshInterval = 60
    @State private var tempSourceURL = ""
    @State private var tempRefreshInterval = 60
    @State private var showingAlert = false
    var loadQuizzes: () -> Void

    var body: some View {
        VStack {
            TextField("Source URL", text: $tempSourceURL)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onAppear {
                    tempSourceURL = sourceURL
                }
            TextField("Refresh Interval (seconds)", value: $tempRefreshInterval, formatter: NumberFormatter())
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onAppear {
                    tempRefreshInterval = refreshInterval
                }
            Button("Check Now") {
                sourceURL = tempSourceURL
                loadQuizzes()
                showingAlert = true
            }
            .padding()
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Update"), message: Text("Data fetched from the new source."), dismissButton: .default(Text("OK")))
            }
            Button("Save Settings") {
                sourceURL = tempSourceURL
                refreshInterval = tempRefreshInterval
                showingAlert = true
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
