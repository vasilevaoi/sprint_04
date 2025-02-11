import UIKit

final class MovieQuizViewController: UIViewController {
    @IBOutlet private var noButton: UIButton!
    @IBOutlet private var yesButton: UIButton!
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var counterLabel: UILabel!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var textLabel: UILabel!
    
    private var currentQuestionIndex = 0
    private var currentQuestion: QuizQuestion?
    
    private var correctAnswers = 0
    private var questionsCount = 10
    
    private var questionFactory: QuestionFactory?
    private var alertPresenter: AlertPresenter?
    private var statisticService: StatisticService?
    // MARK: - Lifecycle
    override var preferredStatusBarStyle: UIStatusBarStyle {
      return .lightContent
     }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        questionFactory = QuestionFactoryImpl(moviesLoader: MoviesLoader(), delegate: self)
        statisticService = StatisticServiceImpl()
        
        noButton.layer.masksToBounds=true
        noButton.layer.cornerRadius = 15
        yesButton.layer.masksToBounds=true
        yesButton.layer.cornerRadius = 15
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 20
        
        self.questionFactory?.requestNextQuestion()
        alertPresenter =  AlertPresenterImpl(viewController: self)
        loadData()
        activityIndicator.hidesWhenStopped = true
    }

    
    @IBAction private func noButtonClicked(_ sender: UIButton) {
        let givenAnswer = false
        showAnswerResult(isCorrect: givenAnswer == currentQuestion?.correctAnswer)
    }
    
    @IBAction private func yesButtonClicked(_ sender: UIButton) {
        let givenAnswer = true
        showAnswerResult(isCorrect: givenAnswer == currentQuestion?.correctAnswer)
    }
    private func showLoadingIndicator(){
        activityIndicator.startAnimating()
    }
    
    private func hideLoadingIndicator() {
        activityIndicator.stopAnimating()
        
    }
    
    private func loadData() {
        showLoadingIndicator()
        questionFactory?.loadData()
    }
    
    private func showNetworkError(message: String){
        showLoadingIndicator()
        
        let alertModel = AlertModel(
            title: "Ошибка",
            message: message,
            buttonText: "Попробовать еще раз",
            actionButton: {[weak self] in
                self?.currentQuestionIndex = 0
                self?.correctAnswers = 0
                self?.questionFactory?.requestNextQuestion()
                self?.loadData()
            }
        )
        
        alertPresenter?.show(alertModel: alertModel)
    }
    
    private func show(quiz step: QuizStepViewModel) {
        imageView.image = step.image
        textLabel.text = step.question
        counterLabel.text = step.questionNumber
        imageView.layer.borderWidth = 0
        imageView.layer.borderColor = UIColor.white.cgColor
    }
    
    
    private func convert(model: QuizQuestion) -> QuizStepViewModel {
        let questionStep = QuizStepViewModel(
            image: UIImage(data: model.image) ?? UIImage(),
            question: model.text,
            questionNumber: "\(currentQuestionIndex + 1)/\(questionsCount)")
        return questionStep
    }
    
    private func showAnswerResult(isCorrect: Bool) {
        if isCorrect {
            correctAnswers += 1
        }
        
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 8
        imageView.layer.borderColor = isCorrect ? UIColor.ypGreen.cgColor : UIColor.ypRed.cgColor
        noButton.isEnabled = false
        yesButton.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showNextQuestionOrResults()
            self.noButton.isEnabled = true
            self.yesButton.isEnabled = true
        }
    }
    
    private func showNextQuestionOrResults() {
        
        if currentQuestionIndex == questionsCount - 1 {
            showFinalResults()
        } else {
            currentQuestionIndex += 1
            showLoadingIndicator()
            questionFactory?.requestNextQuestion()
        }
    }
    
    private func showFinalResults() {
        hideLoadingIndicator()
        
        statisticService?.store(correct: correctAnswers, total: questionsCount)
        
        let alertModel = AlertModel(
            title: "Игра окончена",
            message: makeResultMassage(),
            buttonText: "OK",
            actionButton: { [weak self] in
                self?.currentQuestionIndex = 0
                self?.correctAnswers = 0
                self?.questionFactory?.requestNextQuestion()
            }
        )
        
        
        alertPresenter?.show(alertModel: alertModel)
    }
    
    private func makeResultMassage() -> String {
        hideLoadingIndicator()
        
        guard let statisticService = statisticService, let bestGame = statisticService.bestGame else {
            assertionFailure("error massage")
            return ""
        }
        
        let result = "Ваш результат: \(correctAnswers)/\(questionsCount)"
        let gamesCount = "Количество сыгранных квизов: \(statisticService.gameCount)"
        let record = "Рекорд: \(bestGame.correct)/\(bestGame.total) (\(bestGame.date.dateTimeString))"
        let totalAccuracy = "Средняя точность: \(String(format: "%.2f", statisticService.totalAccuracy))%"
        
        let resultMassage = [
            result, gamesCount, record, totalAccuracy
        ].joined(separator: "\n")
        
        return resultMassage
    }
}

extension MovieQuizViewController: QuestionFactoryDelegate {
    
    func didReceiveNextQuestion(question: QuizQuestion) {
        hideLoadingIndicator()
        
        self.currentQuestion = question
        let viewModel = self.convert(model: question)
        self.show(quiz: viewModel)
    }
    
    func didLoadDataFromServer(){
        hideLoadingIndicator()
        
        activityIndicator.isHidden = true
        questionFactory?.requestNextQuestion()
    }
    
    func didFailToLoadData(with error: Error){
        hideLoadingIndicator()
        
        showNetworkError(message: error.localizedDescription)
    }
}



