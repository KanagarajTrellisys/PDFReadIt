//
//  BookViewController.swift
//  BookReader
//
//  Created by Kishikawa Katsumi on 2017/07/03.
//  Copyright © 2017 Kishikawa Katsumi. All rights reserved.
//

import MessageUI
import PDFKit
import UIKit
@objcMembers
open class PDFReaderViewController: UIViewController,UIScrollViewDelegate {

    // MARK: - Static members
    static public func instantiateViewController(with document: PDFDocument) -> UINavigationController {
        return instantiateViewController(with: document, isNeedToOverwriteDocument: true)
    }

    static public func instantiateViewController(with document: PDFDocument,
                                                 isNeedToOverwriteDocument: Bool) -> UINavigationController {
        guard let navigationController = UIStoryboard(name: "PDFReadIt", bundle: Bundle(for: self))
            .instantiateInitialViewController() as? UINavigationController,
            let viewController = navigationController.topViewController as? Self else {
                fatalError("Unable to instantiate PDFReaderViewController")
        }
        viewController.pdfDocument = document
        viewController.isNeedToOverwriteDocument = isNeedToOverwriteDocument
//      navigationController.navigationBar.barStyle = .blackTranslucent
      navigationController.navigationBar.isTranslucent = true
      navigationController.navigationBar.backgroundColor = UIColor.clear
        return navigationController
    }

    // MARK: - Outlets
    @IBOutlet private weak var pdfView: PDFView!
    public var bIsEnableShare = false
//    @IBOutlet private weak var
    let pdfThumbnailViewContainer = UIScrollView()
//    @IBOutlet private weak var
    let pdfThumbnailView = PDFThumbnailView()
    @IBOutlet private weak var pdfThumbnailViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var titleLabelContainer: UIView!
    @IBOutlet private weak var pageNumberLabel: UILabel!
    @IBOutlet private weak var pageNumberLabelContainer: UIView!

    @IBOutlet private weak var thumbnailGridViewConainer: UIView!
    @IBOutlet private weak var outlineViewConainer: UIView!
    @IBOutlet private weak var bookmarkViewConainer: UIView!
    @IBOutlet private weak var activityIndicatorContainerView: UIView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    // MARK: - Constants
    let pdfViewGestureRecognizer = PDFViewGestureRecognizer()
    let barHideOnTapGestureRecognizer = UITapGestureRecognizer()
    private let pdfDrawer = PDFDrawer()
    private let tableOfContentsToggleSegmentedControl: UISegmentedControl = {
        let bundle = Bundle(for: PDFReaderViewController.self)
        let segmentedControl = UISegmentedControl(items: [
            UIImage(named: "PDFReaderNavigationGrid", in: bundle, compatibleWith: nil) as Any,
            UIImage(named: "PDFReaderNavigationList", in: bundle, compatibleWith: nil) as Any,
            UIImage(named: "PDFReaderBookmarkDefault", in: bundle, compatibleWith: nil) as Any
        ])
        return segmentedControl
    }()
    let thumbnailSize: Int = 70
    let pdfThumbnailPerPagePadding = 2
    var previousPage:PDFPage?
    // MARK: - Variables
    /// Set this flag to false if you don't want to overwrite opened document (for example with drawings on it)
    var isNeedToOverwriteDocument = true
    var pdfPrevPageChangeSwipeGestureRecognizer: PDFPageChangeSwipeGestureRecognizer?
    var pdfNextPageChangeSwipeGestureRecognizer: PDFPageChangeSwipeGestureRecognizer?
    private(set) var pdfDocument: PDFDocument?
    private var bookmarkButton: UIBarButtonItem!
    private var searchNavigationController: UINavigationController?
    lazy private var drawingGestureRecognizer: DrawingGestureRecognizer = {
        let recognizer = DrawingGestureRecognizer()
        pdfView.addGestureRecognizer(recognizer)
        recognizer.drawingDelegate = pdfDrawer
        pdfDrawer.pdfView = pdfView
        return recognizer
    }()
    private var shouldUpdatePDFScrollPosition = true

    open var postDismissAction: ((PDFReaderViewController) -> Void)?

    // MARK: - Lifecycle
    override open func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupEvents()
        setDefaultUIState()
    }

    // This code is required to fix PDFView Scroll Position when NOT using pdfView.usePageViewController(true)
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shouldUpdatePDFScrollPosition = false
    }

    // This code is required to fix PDFView Scroll Position when NOT using pdfView.usePageViewController(true)
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if shouldUpdatePDFScrollPosition {
            fixPDFViewScrollPosition()
        }
    }

    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        adjustThumbnailViewHeight()
    }

    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        pdfView.autoScales = true // This call is required to fix PDF document scale, seems to be bug inside PDFKit
      
      if (size.width > self.view.frame.size.width) {
              print("Landscape")
        if pdfView.isUsingPageViewController == true {
            pdfView.usePageViewController(false, withViewOptions: nil)
            pdfView.displayMode = .twoUp
            pdfView.backgroundColor = UIColor.init(hexStr: "1b1b1b")
            thumbnailGridViewConainer.backgroundColor = UIColor.init(hexStr: "1b1b1b")
//            pdfThumbnailView.backgroundColor = UIColor.init(hexStr: "1b1b1b")
//            pdfThumbnailViewContainer.backgroundColor = UIColor.init(hexStr: "1b1b1b")
          pdfThumbnailViewContainer.backgroundColor = UIColor.init(red: 27/255, green: 27/255, blue: 27/255, alpha: 0.6)
          pdfThumbnailView.backgroundColor = UIColor.init(red: 27/255, green: 27/255, blue: 27/255, alpha: 0.6)
            pdfView.superview?.backgroundColor = UIColor.init(hexStr: "1b1b1b")
        }
          } else {
              print("Portrait")
            if pdfView.isUsingPageViewController == false {
              pdfView.usePageViewController(true, withViewOptions: nil)
            }
          }
    }

    override open func willTransition(to newCollection: UITraitCollection,
                                      with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
            self.adjustThumbnailViewHeight()
        })
    }

    override open func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? PDFThumbnailGridViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        } else if let viewController = segue.destination as? PDFOutlineViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        } else if let viewController = segue.destination as? PDFBookmarkViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        }
    }
  
  //MARK:- get PDF pages
  
  func getPDFPages() -> [AnyHashable:Any] {
      var pdfPages : Dictionary = Dictionary<AnyHashable,Any>()
 
      for i in 0..<pdfView.document!.pageCount
        {
          let page = pdfView.document?.page(at: i)
          pdfPages["\(i)"] = page! as PDFPage
       }
      return pdfPages
  }
  
    // MARK: - UI
    func setupUI() {

        pdfView.document = pdfDocument
        titleLabel.text = pdfDocument?.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ??
            pdfDocument?.documentURL?.lastPathComponent

        if titleLabel.text == nil {
            titleLabel.isHidden = true
        }

        
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysAsBook = true
        pdfView.displayDirection = .horizontal
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = false
        pdfView.backgroundColor =  UIColor.init(hexStr: "1b1b1b")
        pdfView.superview?.backgroundColor = UIColor.init(hexStr: "1b1b1b")

      
        let pdfPrevPageChangeSwipeGestureRecognizer = PDFPageChangeSwipeGestureRecognizer(pdfView: pdfView)
        pdfPrevPageChangeSwipeGestureRecognizer.direction = .left
        pdfView.addGestureRecognizer(pdfPrevPageChangeSwipeGestureRecognizer)
        self.pdfPrevPageChangeSwipeGestureRecognizer = pdfPrevPageChangeSwipeGestureRecognizer

        let pdfNextPageChangeSwipeGestureRecognizer = PDFPageChangeSwipeGestureRecognizer(pdfView: pdfView)
        pdfNextPageChangeSwipeGestureRecognizer.direction = .right
        pdfView.addGestureRecognizer(pdfNextPageChangeSwipeGestureRecognizer)
        self.pdfNextPageChangeSwipeGestureRecognizer = pdfNextPageChangeSwipeGestureRecognizer
        
        pdfView.usePageViewController(true, withViewOptions: getPDFPages())
        
      
//        pdfThumbnailView.layoutMode = .horizontal
//        pdfThumbnailView.pdfView = pdfView
//        pdfThumbnailView.thumbnailSize = CGSize.init(width: 80, height: 130)
        setupThumbnailView()
   
        titleLabelContainer.layer.cornerRadius = 4
        pageNumberLabelContainer.layer.cornerRadius = 4
      
    }
  
   func setupThumbnailView() {
//    pdfThumbnailView = PDFThumbnailView()
      pdfThumbnailView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
          pdfThumbnailView.heightAnchor.constraint(equalToConstant: CGFloat(thumbnailSize)),
        pdfThumbnailView.widthAnchor.constraint(equalToConstant: CGFloat((pdfView.document!.pageCount)*(thumbnailSize + pdfThumbnailPerPagePadding))),
      ])
//    pdfThumbnailViewContainer = UIScrollView()
      pdfThumbnailViewContainer.delegate = self
      pdfThumbnailViewContainer.isScrollEnabled = true
      pdfThumbnailViewContainer.translatesAutoresizingMaskIntoConstraints = false
    pdfThumbnailViewContainer.backgroundColor = UIColor.init(red: 27/255, green: 27/255, blue: 27/255, alpha: 0.6)//UIColor.init(hexStr: "1b1b1b")
      pdfThumbnailViewContainer.addSubview(pdfThumbnailView)

      pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.backgroundColor = UIColor.init(red: 27/255, green: 27/255, blue: 27/255, alpha: 0.6)//UIColor.init(hexStr: "1b1b1b")
      pdfThumbnailView.layoutMode = .horizontal
//      pdfThumbnailView.thumbnailSize = CGSize(width: 80, height: 130)
      pdfThumbnailView.thumbnailSize = CGSize(width: thumbnailSize, height: thumbnailSize)
    pdfThumbnailView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
//    pdfThumbnailViewContainer.contentSize = CGSize.init(width: CGFloat((pdfView.document!.pageCount)*(thumbnailSize + pdfThumbnailPerPagePadding)), height: 130)
      NSLayoutConstraint.activate([
          pdfThumbnailView.leadingAnchor.constraint(equalTo: pdfThumbnailViewContainer.leadingAnchor),
          pdfThumbnailView.trailingAnchor.constraint(equalTo: pdfThumbnailViewContainer.trailingAnchor),
          pdfThumbnailView.topAnchor.constraint(equalTo: pdfThumbnailViewContainer.topAnchor ,constant: 15),
          pdfThumbnailView.bottomAnchor.constraint(equalTo: pdfThumbnailViewContainer.bottomAnchor)
      ])
    self.view.addSubview(pdfThumbnailViewContainer)

    NSLayoutConstraint.activate([
      pdfThumbnailViewContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      pdfThumbnailViewContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      pdfThumbnailViewContainer.heightAnchor.constraint(equalToConstant: CGFloat(100)),
      pdfThumbnailViewContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
    ])
  }
    
    func setupEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(pdfViewPageChanged(notification:)),
                                               name: .PDFViewPageChanged,
                                               object: nil)

        barHideOnTapGestureRecognizer.addTarget(self, action: #selector(gestureRecognizedToggleVisibility(gestureRecognizer:)))
        barHideOnTapGestureRecognizer.numberOfTapsRequired = 1
        barHideOnTapGestureRecognizer.delegate = self
        pdfView.addGestureRecognizer(barHideOnTapGestureRecognizer)

        for segmentIndex in 0..<tableOfContentsToggleSegmentedControl.numberOfSegments {
            tableOfContentsToggleSegmentedControl.setWidth(50.0, forSegmentAt: segmentIndex)
        }
        tableOfContentsToggleSegmentedControl.selectedSegmentIndex = 0
        tableOfContentsToggleSegmentedControl.addTarget(self,
                                                        action: #selector(toggleTableOfContentsView(sender:)),
                                                        for: .valueChanged)
    }

    // MARK: - Notification Events
    func pdfViewPageChanged(notification: Notification) {
        if pdfViewGestureRecognizer.isTracking {
            hideBars()
        }
        updateBookmarkStatus()
        updatePageNumberLabel()
        updateThumbnailView()
    }

    func updateThumbnailView() {
        
    }
    // MARK: - Actions
    func resume(sender: UIBarButtonItem) {
        setDefaultUIState()
    }

    func back(sender: UIBarButtonItem) {
        dismissModule(animated: true)
    }

    func showTableOfContents(sender: UIBarButtonItem) {
        showTableOfContents()
    }

    func showActionMenu(sender: UIBarButtonItem) {

        guard let documentToShare = pdfDocument else {
            print("Unable to share: pdfDocument is nil")
            return
        }

        let viewController = ActionMenuViewController(nibName: String(describing: ActionMenuViewController.self),
                                                      bundle: Bundle(for: Self.self),
                                                      documentToShare: documentToShare,
                                                      in: pdfView)
        viewController.delegate = self

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .popover
        navigationController.popoverPresentationController?.barButtonItem = sender
        navigationController.popoverPresentationController?.permittedArrowDirections = .up
//        navigationController.popoverPresentationController?.delegate = self
        present(navigationController, animated: true)
    }

    func annotateAction(sender: UIBarButtonItem) {
        enableAnnotationMode()
    }

    func showAppearanceMenu(sender: UIBarButtonItem) {
        guard let viewController = storyboard?.instantiateViewController(withIdentifier: "AppearanceViewController")
            as? AppearanceViewController else { return }
        viewController.modalPresentationStyle = .popover
        viewController.preferredContentSize = CGSize(width: 300, height: 44)
        viewController.popoverPresentationController?.barButtonItem = sender
        viewController.popoverPresentationController?.permittedArrowDirections = .up
        viewController.popoverPresentationController?.delegate = self
        present(viewController, animated: true, completion: nil)
    }

    func showSearchView(sender: UIBarButtonItem) {
        if let searchNavigationController = self.searchNavigationController {
            present(searchNavigationController, animated: true, completion: nil)
        } else if let navigationController =
            storyboard?.instantiateViewController(withIdentifier: "PDFSearchViewController") as? UINavigationController,
            let searchViewController = navigationController.topViewController as? PDFSearchViewController {
            searchViewController.pdfDocument = pdfDocument
            searchViewController.delegate = self
            present(navigationController, animated: true, completion: nil)

            searchNavigationController = navigationController
        }
    }

    func addOrRemoveBookmark(sender: UIBarButtonItem) {

        guard let documentURL = pdfDocument?.documentURL?.absoluteString,
            let currentPage = pdfView.currentPage,
            let pageIndex = pdfDocument?.index(for: currentPage) else { return }

        let bundle = Bundle(for: Self.self)
        var bookmarks = UserDefaults.standard.array(forKey: documentURL) as? [Int] ?? [Int]()
        if let index = bookmarks.firstIndex(of: pageIndex) {
            bookmarks.remove(at: index)
            UserDefaults.standard.set(bookmarks, forKey: documentURL)
            bookmarkButton.image = UIImage(named: "PDFReaderBookmarkDefault", in: bundle, compatibleWith: nil)
        } else {
            UserDefaults.standard.set((bookmarks + [pageIndex]).sorted(), forKey: documentURL)
            bookmarkButton.image = UIImage(named: "PDFReaderBookmarkAdded", in: bundle, compatibleWith: nil)
        }
    }

    func toggleTableOfContentsView(sender: UISegmentedControl) {
        pdfView.isHidden = true
        titleLabelContainer.alpha = 0
        pageNumberLabelContainer.alpha = 0

        if tableOfContentsToggleSegmentedControl.selectedSegmentIndex == 0 {
            thumbnailGridViewConainer.isHidden = false
            outlineViewConainer.isHidden = true
            bookmarkViewConainer.isHidden = true
        } else if tableOfContentsToggleSegmentedControl.selectedSegmentIndex == 1 {
            thumbnailGridViewConainer.isHidden = true
            outlineViewConainer.isHidden = false
            bookmarkViewConainer.isHidden = true
        } else {
            thumbnailGridViewConainer.isHidden = true
            outlineViewConainer.isHidden = true
            bookmarkViewConainer.isHidden = false
        }
    }

    func gestureRecognizedToggleVisibility(gestureRecognizer: UITapGestureRecognizer) {
        guard let navigationController = navigationController else { return }
        if navigationController.navigationBar.alpha > 0 {
            hideBars()
        } else {
            showBars()
        }
    }


    func dismissModule(animated: Bool = true) {

        let dismissBlock = {
            switch self.parent {
            case let navController as UINavigationController where !navController.viewControllers.isEmpty &&
                navController.viewControllers.first != self:
                navController.popViewController(animated: animated)
            case _ where self.parent?.presentingViewController != nil ||
                self.parent?.popoverPresentationController != nil:
                if self.navigationController == nil {
                    self.dismiss(animated: animated)
                } else {
                    self.navigationController?.dismiss(animated: animated)
                }
            case let navigationController as UINavigationController where !navigationController.viewControllers.isEmpty:
                navigationController.popViewController(animated: animated)
            default:
                self.dismiss(animated: animated)
            }
            self.postDismissAction?(self)
        }

        if isNeedToOverwriteDocument,
            let documentURL = pdfDocument?.documentURL,
            documentURL.isFileURL {

            showWaitingView()

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if FileManager.default.fileExists(atPath: documentURL.path) {
                        try FileManager.default.removeItem(at: documentURL)
                    }
                    self.pdfDocument?.write(to: documentURL)
                } catch {
                    print(error)
                }

                DispatchQueue.main.async {
                    self.hideWaitingView()
                    dismissBlock()
                }
            }
        } else {
            dismissBlock()
        }
    }

    func showWaitingView() {
        navigationItem.leftBarButtonItems?.forEach { $0.isEnabled = false }
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
        activityIndicatorContainerView.isHidden = false
        activityIndicator.startAnimating()
    }

    func hideWaitingView() {
        activityIndicator.stopAnimating()
        activityIndicatorContainerView.isHidden = true
        navigationItem.leftBarButtonItems?.forEach { $0.isEnabled = true }
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
    }

    func showBars(needsToHideNavigationBar: Bool = true) {
        guard let navigationController = navigationController else { return }
        UIView.animate(withDuration: CATransaction.animationDuration()) {
            if needsToHideNavigationBar {
                navigationController.navigationBar.alpha = 1
            }
            self.pdfThumbnailViewContainer.alpha = 1
            self.titleLabelContainer.alpha = 0
            self.pageNumberLabelContainer.alpha = 1
        }
    }

    func hideBars(needsToHideNavigationBar: Bool = true) {
        guard let navigationController = navigationController else { return }
        UIView.animate(withDuration: CATransaction.animationDuration()) {
            if needsToHideNavigationBar {
                navigationController.navigationBar.alpha = 0
            }
            self.pdfThumbnailViewContainer.alpha = 0
            self.titleLabelContainer.alpha = 0
            self.pageNumberLabelContainer.alpha = 0
        }
    }

    // MARK: - Other
    func setDefaultUIState() {

        let bundle = Bundle(for: Self.self)

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(image: UIImage(named: "PDFReaderNavigationBack", in: bundle, compatibleWith: nil),
                            style: .plain,
                            target: self,
                            action: #selector(back(sender:))),
            UIBarButtonItem(barButtonSystemItem: .bookmarks,
                            target: self,
                            action: #selector(showTableOfContents(sender:))),
            UIBarButtonItem(barButtonSystemItem: .search,
                            target: self,
                            action: #selector(showSearchView(sender:)))
        ]

        bookmarkButton =
            UIBarButtonItem(image: UIImage(named: "PDFReaderBookmarkDefault", in: bundle, compatibleWith: nil),
                            style: .plain,
                            target: self,
                            action: #selector(addOrRemoveBookmark(sender:)))
        
        let brightess = UIBarButtonItem(image: UIImage(named: "PDFReaderBrightness", in: bundle, compatibleWith: nil),
                                        style: .plain,
                                        target: self,
                                        action: #selector(showAppearanceMenu(sender:)))
        
        let share = UIBarButtonItem(barButtonSystemItem: .action,
                                    target: self,
                                    action: #selector(showActionMenu(sender:)))
        let annotation = UIBarButtonItem(image: UIImage(named: "PDFReaderAnnotation", in: bundle, compatibleWith: nil),
                        style: .plain,
                        target: self,
                        action: #selector(annotateAction(sender:)))
        
        var rightBarButtons = [UIBarButtonItem]()
        rightBarButtons.append(annotation)
        if bIsEnableShare {
            rightBarButtons.append(share)
        }
        rightBarButtons.append(bookmarkButton)
        rightBarButtons.append(brightess)
        navigationItem.rightBarButtonItems = rightBarButtons
      
        pdfThumbnailViewContainer.alpha = 1

        pdfView.isHidden = false
        titleLabelContainer.alpha = 0
        pageNumberLabelContainer.alpha = 1
        thumbnailGridViewConainer.isHidden = true
        outlineViewConainer.isHidden = true

        barHideOnTapGestureRecognizer.isEnabled = true

        updateBookmarkStatus()
        updatePageNumberLabel()
    }
}

// MARK: - PDF Navigation
extension PDFReaderViewController {

    func open(page: PDFPage) {
        pdfView.go(to: page)
    }

    func selectAndOpen(selection: PDFSelection) {
        selection.color = .yellow
        pdfView.currentSelection = selection
        pdfView.go(to: selection)
    }

    func open(destination: PDFDestination) {
        pdfView.go(to: destination)
    }

    // MARK: Drawing
    func addDrawingGestureRecognizerToPDFView() {
        drawingGestureRecognizer.isEnabled = true
    }

    func removeDrawingGestureRecognizerFromPDFView() {
        drawingGestureRecognizer.isEnabled = false
    }
}

// MARK: - Private extension of PDFReaderViewController
private extension PDFReaderViewController {

    // This code is required to fix PDFView Scroll Position when NOT using pdfView.usePageViewController(true)
    func fixPDFViewScrollPosition() {
        guard let page = pdfView.document?.page(at: 0) else { return }
        pdfView.go(to: PDFDestination(page: page, at: CGPoint(x: 0, y: page.bounds(for: pdfView.displayBox).height)))
    }

    func showTableOfContents() {
        view.exchangeSubview(at: 0, withSubviewAt: 1)
        view.exchangeSubview(at: 0, withSubviewAt: 2)

        let bundle = Bundle(for: Self.self)
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(image: UIImage(named: "PDFReaderNavigationBack", in: bundle, compatibleWith: nil),
                            style: .plain,
                            target: self,
                            action: #selector(back(sender:))),
            UIBarButtonItem(customView: tableOfContentsToggleSegmentedControl)
        ]
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Resume", comment: ""),
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(resume(sender:)))

        pdfThumbnailViewContainer.alpha = 0
        toggleTableOfContentsView(sender: tableOfContentsToggleSegmentedControl)
        barHideOnTapGestureRecognizer.isEnabled = false
    }

    func adjustThumbnailViewHeight() {
//      if pdfView.isUsingPageViewController == true {
//        pdfThumbnailViewHeightConstraint.constant = 130 //+ view.safeAreaInsets.bottom
//      }else {
//        pdfThumbnailViewHeightConstraint.constant = 100 //+ view.safeAreaInsets.bottom
//      }
    }

    func updateBookmarkStatus() {
        guard let documentURL = pdfDocument?.documentURL?.absoluteString,
            let bookmarks = UserDefaults.standard.array(forKey: documentURL) as? [Int],
            let currentPage = pdfView.currentPage,
            let index = pdfDocument?.index(for: currentPage) else { return }

        let bundle = Bundle(for: Self.self)
        let imageName = bookmarks.contains(index) ? "PDFReaderBookmarkAdded" : "PDFReaderBookmarkDefault"
        bookmarkButton.image = UIImage(named: imageName, in: bundle, compatibleWith: nil)
    }

    func updatePageNumberLabel() {
        guard let currentPage = pdfView.visiblePages.first,
              let index = pdfDocument?.index(for: currentPage),
            let pageCount = pdfDocument?.pageCount, let curPg = pdfView.currentPage?.pageRef?.pageNumber  else {
                pageNumberLabel.text = nil
                return
        }
        
        let desiredRect = CGRect(x: (index * thumbnailSize) + (curPg) * 2 , y: 0, width: Int(pdfThumbnailViewContainer.frame.size.width), height: Int(pdfThumbnailViewContainer.frame.size.height))
        if !pdfThumbnailViewContainer.bounds.contains(desiredRect){
            pdfThumbnailViewContainer.scrollRectToVisible(desiredRect, animated: true)
        }
        
     
//        if pdfView.displayMode == .singlePage || pdfView.displayMode == .singlePageContinuous {
//            pageNumberLabel.text = String("\(index + 1)/\(pageCount)")
//        } else {
//            let currentPagesIndexes = (index > 0 && index < pageCount) ? "\(index + 1)-\(index + 2)" : "\(index + 1)"
//            pageNumberLabel.text = String("\(currentPagesIndexes)/\(pageCount)")
//        }
        pageNumberLabel.text = String("\(curPg)/\(pageCount)")
    }
}
