import SwiftUI

// Struct for each quiz topic
struct QuizTopic: Identifiable, Decodable {
    var id = UUID()
    var title: String
    var description: String
    var iconName: String = "questionmark.circle" // Default icon if not provided in JSON
    var questions: [Question]

    enum CodingKeys: String, CodingKey {
        case title
        case description = "desc"
        case questions
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
            .alert(isPresented: $showingSettings) {
                Alert(title: Text("Settings"), message: Text("Settings go here"), dismissButton: .default(Text("OK")))
            }
            .onAppear(perform: loadQuizzes)
            .sheet(item: $selectedQuiz) { quiz in
                QuestionView(quiz: quiz)
            }
        }
    }

    func loadQuizzes() {
            guard let url = URL(string: "http://tednewardsandbox.site44.com/questions.json") else {
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
                    }
                } catch {
                    print("Error decoding data: \(error)")
                }
            }.resume()
        }
    }


struct QuestionView: View {
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: Int? = nil
    @State private var showingAnswer = false

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
                showingAnswer: $showingAnswer
            )
        }
    }
}

struct AnswerView: View {
    var quiz: QuizTopic
    @Binding var currentQuestionIndex: Int
    @Binding var selectedAnswer: Int?
    @Binding var showingAnswer: Bool

    var body: some View {
        VStack {
            Text(quiz.questions[currentQuestionIndex].text)
                .font(.largeTitle)
            Text("Your answer: \(quiz.questions[currentQuestionIndex].answers[selectedAnswer ?? 0])")
            if let correctAnswerIndex = quiz.questions[currentQuestionIndex].correctAnswerIndex {
                Text("Correct answer: \(quiz.questions[currentQuestionIndex].answers[correctAnswerIndex])")
            }
            Button("Next") {
                if currentQuestionIndex < quiz.questions.count - 1 {
                    currentQuestionIndex += 1
                    selectedAnswer = nil
                    showingAnswer = false
                } else {
                    // Navigate to FinishedView
                }
            }
        }
        .padding()
    }
}

struct FinishedView: View {
    var score: Int
    var total: Int

    var body: some View {
        VStack {
            Text("Finished!")
                .font(.largeTitle)
            Text("Your score: \(score) out of \(total)")
            Button("Back to Quiz List") {
                // Handle navigation back to quiz list
            }
        }
        .padding()
    }
}

struct SettingsView: View {
    @State private var sourceURL: String = "http://tednewardsandbox.site44.com/questions.json"
    @State private var showingAlert = false

    var body: some View {
        VStack {
            TextField("Source URL", text: $sourceURL)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Check Now") {
                // Trigger data fetch
                showingAlert = true
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Update"), message: Text("Data fetched from the new source."), dismissButton: .default(Text("OK")))
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
