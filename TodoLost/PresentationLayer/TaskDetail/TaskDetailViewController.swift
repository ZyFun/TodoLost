//
//  TaskDetailViewController.swift
//  TodoLost
//
//  Created by Дмитрий Данилин on 18.06.2023.
//

import UIKit

/// Протокол отображения данных ViewCintroller-a
protocol TaskDetailView: AnyObject {
    func updateView(_ viewModel: TaskDetailViewModel?)
    
    func setPlaceholderToTextEditor()
    func removePlaceholderToTextEditor()
    
    func activateSaveButton()
    func deactivateSaveButton()
    
    func activateDeleteButton()
    func deactivateDeleteButton()
    
    func setDeadlineWith(_ dateSelection: UICalendarSelectionSingleDate)
}

final class TaskDetailViewController: UIViewController {
    
    // MARK: - Public property
    
    var presenter: TaskDetailPresenter?
    var observerKeyboard: INotificationKeyboardObserver?
    
    // MARK: - Private property
    
    private var currentId = ""
    private var currentImportance: Importance = .normal
    
    // FIXME: Костыль. Нужно пересмотреть эти 2 свойства, и например делать свитчем сброс и установку именно в модели через презентер
    /// Используется при переключении свитча, чтобы сбросить текущую дату при выключении дедлайна и сохранить nil
    private var currentDeadline: Date?
    /// Используется для временного хранения даты при переключении свича
    /// - свич очищает текущий дедлайн, чтобы при сохранении записать nil. И чтобы вернуть
    /// значение обратно, используется это свойство, если пользователь передумал отключать дедлайн
    private var tempDeadline: Date?
    
    private var isCalendarHidden = true
    /// Время выполнения анимаций на экране
    private let duration = 0.3
    
    // MARK: - UIElements
    
    private lazy var cancelBarButton: UIBarButtonItem = {
        UIBarButtonItem(
            title: "Отменить",
            style: .plain,
            target: self,
            action: nil
        )
    }()
    
    private lazy var saveBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            title: "Сохранить",
            style: .done,
            target: self,
            action: #selector(saveButtonPressed)
        )
        
        button.isEnabled = false
        return button
    }()
    
    private lazy var endEditingGesture: UIGestureRecognizer = {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(endEditing))
        return tapGesture
    }()
    
    /// Используется для возможности менять высоту при отображении и скрытии клавиатуры
    private lazy var bottomScreenConstraint: NSLayoutConstraint = {
        let constraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        constraint.constant = .zero
        return constraint
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = Colors.backPrimary
        return scrollView
    }()
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private let floatingLayoutStack: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fill
        return stackView
    }()
    
    private let textEditorTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        textView.backgroundColor = Colors.backSecondary
        textView.layer.cornerRadius = 16
        textView.textContainerInset = UIEdgeInsets(top: 17, left: 16, bottom: 17, right: 16)
        textView.font = Fonts.body
        return textView
    }()
    
    private let taskSettingsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.backgroundColor = Colors.backSecondary
        stackView.layer.cornerRadius = 16
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private let importanceSettingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let importanceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Важность"
        label.font = Fonts.body
        return label
    }()
    
    private lazy var importanceSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl()
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        let lowImage = Icons.lowImportance.image
        let highImage = Icons.highImportance.image
        
        let normalLabel = UILabel()
        normalLabel.text = "нет"
        
        segmentedControl.insertSegment(with: lowImage, at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: normalLabel.text, at: 1, animated: false)
        segmentedControl.insertSegment(with: highImage, at: 2, animated: false)
        segmentedControl.selectedSegmentIndex = 1
        
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged), for: .valueChanged)
        
        return segmentedControl
    }()
    
    private let separator1: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Colors.supportOverlay
        return view
    }()
    
    private let deadlineSettingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let deadlineStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .leading
        return stackView
    }()
    
    private let deadlineLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Сделать до"
        label.font = Fonts.body
        return label
    }()
    
    private lazy var deadlineDateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        label.text = "error choice data"
        label.font = Fonts.footnote
        label.textColor = Colors.blue
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(deadlineDateTapped))
        
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tapGesture)
        
        return label
    }()
    
    private lazy var deadlineSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        uiSwitch.addTarget(self, action: #selector(deadlineSwitchValueChanged), for: .valueChanged)
        return uiSwitch
    }()
    
    private let separator2: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Colors.supportOverlay
        return view
    }()
    
    // FIXME: ПО каким то причинам выбор даты происходит только при долгом нажатии
    private let calendarView: UICalendarView = {
        let calendarView = UICalendarView()
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.isHidden = true
        return calendarView
    }()
    
    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Удалить", for: .normal)
        button.setTitleColor(Colors.labelTertiary, for: .normal)
        button.backgroundColor = Colors.backSecondary
        button.layer.cornerRadius = 16
        button.isEnabled = false
        button.addTarget(self, action: #selector(deleteButtonPressed), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        presenter?.fetchTask()
        textEditorTextView.delegate = presenter
        setup()
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let device = UIDevice.current
        let orientation = device.orientation
        
        if orientation.isLandscape {
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.alignment = .top
        } else {
            stackView.axis = .vertical
            stackView.distribution = .fill
            stackView.alignment = .fill
        }
    }
    
    // MARK: - Actions
    
    @objc private func endEditing() {
        view.endEditing(true)
    }
    
    @objc private func deadlineSwitchValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            self.deadlineDateLabel.alpha = 0
            self.currentDeadline = self.tempDeadline
            
            UIView.animate(withDuration: 0.3) {
                self.deadlineDateLabel.isHidden = false
            } completion: { _ in
                UIView.animate(withDuration: 0.3) {
                    self.deadlineDateLabel.alpha = 1
                }
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.deadlineDateLabel.isHidden = true
            } completion: { _ in
                self.currentDeadline = nil
            }
            
            hideCalendarAnimate(duration: duration)
        }
        
        activateSaveButton()
    }
    
    @objc private func deadlineDateTapped() {
        if isCalendarHidden {
            showCalendarAnimate(duration: duration)
        } else {
            hideCalendarAnimate(duration: duration)
        }
    }
    
    private func showCalendarAnimate(duration: CGFloat) {
        UIView.animate(withDuration: duration) {
            self.calendarView.isHidden = false
            self.separator2.isHidden = false
        } completion: { _ in
            UIView.animate(withDuration: duration) {
                self.calendarView.alpha = 1
            }
            
            self.isCalendarHidden = false
        }
    }
    
    private func hideCalendarAnimate(duration: CGFloat) {
        UIView.animate(withDuration: duration) {
            self.calendarView.alpha = 0
        } completion: { _ in
            UIView.animate(withDuration: duration) {
                self.calendarView.isHidden = true
                self.separator2.isHidden = true
            }
            
            self.isCalendarHidden = true
        }
    }
    
    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0: currentImportance = .low
        case 1: currentImportance = .normal
        case 2: currentImportance = .important
        default:
            break
        }
        activateSaveButton()
    }
    
    @objc private func saveButtonPressed() {
        let todoItem = TodoItem(
            id: currentId,
            text: textEditorTextView.text,
            importance: currentImportance,
            deadline: currentDeadline,
            isDone: false
        )
        
        presenter?.saveTask(item: todoItem)
        deactivateSaveButton()
    }
    
    @objc private func deleteButtonPressed() {
        presenter?.deleteTask(id: currentId)
    }
}

// MARK: - Логика обновления данных View

extension TaskDetailViewController: TaskDetailView {
    
    func setDeadlineWith(_ dateSelection: UICalendarSelectionSingleDate) {
        calendarView.selectionBehavior = dateSelection
    }
    
    func setPlaceholderToTextEditor() {
        textEditorTextView.text = "Что надо сделать?"
        textEditorTextView.textColor = Colors.labelTertiary
    }
    
    func removePlaceholderToTextEditor() {
        textEditorTextView.text = nil
        textEditorTextView.textColor = Colors.labelPrimary
    }
    
    func activateSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    func deactivateSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    func activateDeleteButton() {
        UIView.transition(
            with: deleteButton,
            duration: 0.2,
            options: .transitionCrossDissolve,
            animations: {
                self.deleteButton.setTitleColor(Colors.red, for: .normal)
            }
        ) { _ in
            self.deleteButton.isEnabled = true
        }
    }
    
    func deactivateDeleteButton() {
        UIView.transition(
            with: deleteButton,
            duration: 0.2,
            options: .transitionCrossDissolve,
            animations: {
                self.deleteButton.setTitleColor(Colors.labelTertiary, for: .normal)
            }
        ) { _ in
            self.deleteButton.isEnabled = false
        }
    }
    
    func updateView(_ viewModel: TaskDetailViewModel?) {
        currentId = viewModel?.id ?? UUID().uuidString
        textEditorTextView.text = viewModel?.text
        
        tempDeadline = viewModel?.tempDeadline
        currentDeadline = viewModel?.deadline
        deadlineDateLabel.text = currentDeadline?.toString() ?? tempDeadline?.toString()
        
        currentImportance = viewModel?.importance ?? .normal
        switch currentImportance {
        case .low:
            importanceSegmentedControl.selectedSegmentIndex = 0
        case .normal:
            importanceSegmentedControl.selectedSegmentIndex = 1
        case .important:
            importanceSegmentedControl.selectedSegmentIndex = 2
        }
        
        if viewModel?.deadline != nil {
            deadlineSwitch.setOn(true, animated: false)
            deadlineSwitchValueChanged(deadlineSwitch)
        }
        
        if textEditorTextView.text.isEmpty {
            textEditorTextView.text = "Что надо сделать?"
            textEditorTextView.textColor = Colors.labelTertiary
        } else {
            textEditorTextView.textColor = Colors.labelPrimary
            deleteButton.setTitleColor(Colors.red, for: .normal)
            deleteButton.isEnabled = true
        }
    }
}

// MARK: - Конфигурирование ViewController

private extension TaskDetailViewController {
    /// Метод инициализации VC
    func setup() {
        view.addGestureRecognizer(endEditingGesture)
        setupNavBar()
        setupConstraints()
        setupKeyboardNotificationsObserver()
    }
    
    func setupNavBar() {
        title = "Дело"
        navigationItem.leftBarButtonItem = cancelBarButton
        navigationItem.rightBarButtonItem = saveBarButton
        
        let disabledColor = Colors.labelTertiary
        let disabledTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: disabledColor ?? UIColor.red
        ]
        
        navigationItem.rightBarButtonItem?.setTitleTextAttributes(
            disabledTextAttributes,
            for: .disabled
        )
    }
    
    func setupKeyboardNotificationsObserver() {
        observerKeyboard?.addChangeHeightObserver(
            for: view,
            changeValueFor: bottomScreenConstraint
        )
    }
    
    func setupConstraints() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        stackView.addArrangedSubview(textEditorTextView)
        
        stackView.addArrangedSubview(floatingLayoutStack)
        floatingLayoutStack.addArrangedSubview(taskSettingsStackView)
        floatingLayoutStack.addArrangedSubview(deleteButton)
        
        taskSettingsStackView.addArrangedSubview(importanceSettingView)
        importanceSettingView.addSubview(importanceLabel)
        importanceSettingView.addSubview(importanceSegmentedControl)
        
        taskSettingsStackView.addArrangedSubview(separator1)
        
        taskSettingsStackView.addArrangedSubview(deadlineSettingView)
        deadlineSettingView.addSubview(deadlineStackView)
        deadlineStackView.addArrangedSubview(deadlineLabel)
        deadlineStackView.addArrangedSubview(deadlineDateLabel)
        deadlineSettingView.addSubview(deadlineSwitch)
        
        taskSettingsStackView.addArrangedSubview(separator2)
        taskSettingsStackView.addArrangedSubview(calendarView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomScreenConstraint,
            
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            
            textEditorTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            importanceSettingView.heightAnchor.constraint(equalToConstant: 56),
            
            importanceLabel.centerYAnchor.constraint(equalTo: importanceSettingView.centerYAnchor),
            importanceLabel.leadingAnchor.constraint(equalTo: importanceSettingView.leadingAnchor),
            
            importanceSegmentedControl.heightAnchor.constraint(equalToConstant: 36),
            importanceSegmentedControl.widthAnchor.constraint(equalToConstant: 150),
            importanceSegmentedControl.centerYAnchor.constraint(equalTo: importanceSettingView.centerYAnchor),
            importanceSegmentedControl.trailingAnchor.constraint(equalTo: importanceSettingView.trailingAnchor),
            
            separator1.heightAnchor.constraint(equalToConstant: 1),
            
            deadlineSettingView.heightAnchor.constraint(equalToConstant: 56),
            
            deadlineStackView.centerYAnchor.constraint(equalTo: deadlineSettingView.centerYAnchor),
            deadlineStackView.leadingAnchor.constraint(equalTo: deadlineSettingView.leadingAnchor),
            
            deadlineSwitch.centerYAnchor.constraint(equalTo: deadlineSettingView.centerYAnchor),
            deadlineSwitch.trailingAnchor.constraint(equalTo: deadlineSettingView.trailingAnchor),
            
            separator2.heightAnchor.constraint(equalToConstant: 1),
            
            deleteButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
}
