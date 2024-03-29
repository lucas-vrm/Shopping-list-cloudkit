// using this tutorial: https://www.ralfebert.de/ios/tutorials/cloudkit/
import UIKit
import CloudKit

struct Errand {
    fileprivate static let recordType = "Errand"
    //fileprivate static let keys = ( name : "name" )
    fileprivate static let name = "name"

    var record: CKRecord
    
    init(record: CKRecord) {
        self.record = record
    }
    
    init(){
        self.record = CKRecord(recordType: Errand.recordType)
    }
    var name : String {
        get {
            //return self.record.value(forKey: Errand.keys.name) as! String
            return self.record.value(forKey: Errand.name) as! String
        } set {
            //self.record.setValue(newValue, forKey: Errand.keys.name)
            self.record.setValue(newValue, forKey: Errand.name)
        }
    }

}

class ErrandsModel {
    
    private let database = CKContainer.default().privateCloudDatabase
    var errands = [Errand]() {
        didSet {
            self.notificationQueue.addOperation {
                self.onChange?()
            }
        }
    }

    var onChange : (() -> Void)?
    var onError : ((Error) -> Void)?
    var notificationQueue = OperationQueue.main
    
    var records = [CKRecord]()
    var insertedObjects = [Errand]()
    var deletedObjectsIds = Set<CKRecordID>()
    
    init() {
    }

    func addErrand(name : String) {
        var errand = Errand()
        errand.name = name
        database.save(errand.record){(records, error) in
            guard error == nil else {
                self.handle(error: error)
                return
            }
        //self.refresh()
        }
        insertedObjects.append(errand)
        updateErrands()
    }

    func delete(at index : Int) {
        let recordId = self.errands[index].record.recordID
        database.delete(withRecordID: recordId){ (recordId, error) in
            guard error == nil else {
                self.handle(error: error!)
                return
            }
            
        }
        deletedObjectsIds.insert(recordId)
        updateErrands()
        
        //self.errands.remove(at: index)
    }
    
    fileprivate func handle(error: Error?) {
        notificationQueue.addOperation {
            self.onError?(error!)

        }
    }
    fileprivate func updateErrands(){
        var knownIds = Set(records.map{ $0.recordID })
        //remove objects from our local list once we see them returned from the cloudkit storage
        insertedObjects.removeAll { (errand) in
            knownIds.contains(errand.record.recordID)
        }
        knownIds.formUnion(insertedObjects.map{ $0.record.recordID})
        //remove objects from our local list once we see them not being returned from the cloudkit storage
        self.deletedObjectsIds.formIntersection(knownIds)
        
        var errands = records.map { (record) in Errand(record: record)}
        errands.append(contentsOf: insertedObjects)
        errands.removeAll { (errand) in
            deletedObjectsIds.contains(errand.record.recordID)
            
        }
        self.errands = errands
        
        debugPrint("Tracking local objects \(self.insertedObjects) \(self.deletedObjectsIds)")
        
    }

    @objc func refresh() {
        let query = CKQuery(recordType: Errand.recordType, predicate: NSPredicate(value: true))
        database.perform(query, inZoneWith: nil) { (records, error) in
            guard let records = records, error == nil else {
                self.handle(error: error)
                return
            }
            
            self.records = records
            self.updateErrands()
            
        }
    }

}

class ErrandsTableViewController: UITableViewController {

    var model = ErrandsModel()

    // MARK: - UIViewController Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.model.onError = { error in
            let alert = UIAlertController(title: "Error", message: String(describing: error), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true, completion: nil)
            self.refreshControl!.endRefreshing()
        }

        self.model.onChange = {
            self.tableView.reloadData()
            self.refreshControl!.endRefreshing()
        }

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self.model, action: #selector(ErrandsModel.refresh), for: .valueChanged)
        self.refreshControl = refreshControl

        self.model.refresh()
    }

    // MARK: - Actions

    @IBAction func addErrand() {

        let alertController = UIAlertController(title: "Add Errand", message: "", preferredStyle: .alert)
        alertController.addTextField(configurationHandler: nil)
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            let name = alertController.textFields!.first!.text!
            if name.count > 0 {
                self.model.addErrand(name: name)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .default)

        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }

    // MARK: - Protocol UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.model.errands.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)

        let errand = model.errands[indexPath.row]
        cell.textLabel?.text = errand.name

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.model.delete(at: indexPath.row)
            // tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

}
