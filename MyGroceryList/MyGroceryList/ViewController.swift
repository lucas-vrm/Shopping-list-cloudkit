//
//  ViewController.swift
//  MyGroceryList
//
//  Created by Karen Lima on 01/10/21.
//

import CloudKit
import UIKit

//transforma em UITableViewDataSource para poder suportar a tableView
class ViewController: UIViewController, UITableViewDataSource {
    
    //cria uma table view no código
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()
    
    //private let database = CKContainer.default().sharedCloudDatabase
    private let database = CKContainer(identifier: "iCloud.iOSExampleGroceryList").publicCloudDatabase
    
    var items = [String]()
    var allRecords = [CKRecord.ID]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Grocery List"
        
        //adiciona a table view no UIViewController
        view.addSubview(tableView)
        tableView.dataSource = self
        
        //esse control faz a tela dar um refresh quando puxa pra baixo
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.refreshControl = control
        
        //Adiciona o botão de adicionar na direita superior
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd))
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteID))
        
        fetchItems()
        //para deletar:
        //database.delete(withRecordID: <#T##CKRecord.ID#>, completionHandler: <#T##(CKRecord.ID?, Error?) -> Void#>)
    }
    
    //aqui faz a query dos dados no cloudkit
    @objc func fetchItems(){
        let query = CKQuery(recordType: "GroceryItem", predicate: NSPredicate(value: true))
        database.perform(query, inZoneWith: nil) { [weak self] records, error in
            guard let records = records, error == nil else { return }
            DispatchQueue.main.async {
                print(records)
                // o  retorno é um array bem grande e confuso, mas queremos pegar só o nome
                self?.items = records.compactMap({ $0.value(forKey: "name") as? String})
                //self?.allRecords = records.compactMap({ $0.value(forKey: "name") as? String})
                print(self?.items)
                //para recarregar a tela depois de fazer a query
                self?.tableView.reloadData()
            }
            
        }
    }
    
    @objc func pullToRefresh(){
        //aciona o control para dar refresh ao puxar
        tableView.refreshControl?.beginRefreshing()
        let query = CKQuery(recordType: "GroceryItem", predicate: NSPredicate(value: true))
        database.perform(query, inZoneWith: nil) { [weak self] records, error in
            guard let records = records, error == nil else { return }
            DispatchQueue.main.async {
                print(records)
                self?.items = records.compactMap({ $0.value(forKey: "name") as? String})
                print(self?.items)
                self?.tableView.reloadData()
                self?.tableView.refreshControl?.endRefreshing()
            }
            
        }
    }
    
    @objc func didTapAdd(){
        let alert = UIAlertController(title: "Add Item", message: nil, preferredStyle: .alert)
        alert.addTextField{ field in
            field.placeholder = "Enter name..."
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            if let field = alert.textFields?.first, let text = field.text, !text.isEmpty {
                self?.saveItem(name: text)
            }
            
        }))
        present(alert, animated: true)
    }
    
    @objc func saveItem(name: String) {
        let record = CKRecord(recordType: "GroceryItem")
        record.setValue(name, forKey: "name")
        allRecords.append(record.recordID)
        database.save(record) { [weak self] record, error in
            if record != nil, error == nil {
                DispatchQueue.main.asyncAfter(deadline: .now()+2) {
                    self?.fetchItems()
                    print("saved")
                }
            
            }
            
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    //MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.textLabel?.text = items[indexPath.row]
        return cell
    }
    
    @objc func deleteID(at index: Int) {
        let recordId = 
    }
    
//    @objc func deleteID(){
//        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: allRecords)
//        operation.savePolicy = .allKeys
//        operation.modifyRecordsResultBlock = { added, deleted, error in
//            if error != nil {
//                print(error) // print error if any
//            } else {
//                // no errors, all set!
//            }
//        }
//        database.add(operation)
//        self.tableView.reloadData()
//        print("Deleted All")
//
//    }
    
}

