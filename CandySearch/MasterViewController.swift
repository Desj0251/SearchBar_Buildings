import UIKit

var filteredCandies: [[String: Any]]?

class MasterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

  // MARK: - Properties
  @IBOutlet var tableView: UITableView!
  @IBOutlet var searchFooter: SearchFooter!
  
  var detailViewController: DetailViewController? = nil
  var jsonArray: [[String:Any]]?
    
  let searchController = UISearchController(searchResultsController: nil)
    
    func requestTask (serverData: Data?, serverResponse: URLResponse?, serverError: Error?) -> Void{
        if serverError != nil {
            self.myCallback(responseString: "", error: serverError?.localizedDescription)
        }else{
            let result = String(data: serverData!, encoding: .utf8)!
            self.myCallback(responseString: result as String, error: nil)
        }
    }
    
    func myCallback(responseString: String, error: String?) {
        if error != nil {
            print("ERROR is " + error!)
        }else{
            if let myData: Data = responseString.data(using: String.Encoding.utf8) {
                do {
                    jsonArray = try JSONSerialization.jsonObject(with: myData, options: []) as? [[String:Any]]
                } catch let convertError {
                    print(convertError.localizedDescription)
                }
            }
        }
        DispatchQueue.main.async() {
            self.tableView.reloadData()
        }
    }
    
  // MARK: - View Setup
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let requestUrl: URL = URL(string: "https://doors-open-ottawa.mybluemix.net/buildings")!
    let myRequest: URLRequest = URLRequest(url: requestUrl)
    let mySession: URLSession = URLSession.shared
    let myTask = mySession.dataTask(with: myRequest, completionHandler: requestTask)
    myTask.resume()
    
    // Setup the Search Controller
    searchController.searchResultsUpdater = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search Buildings"
    navigationItem.searchController = searchController
    definesPresentationContext = true
    
    searchController.searchBar.scopeButtonTitles = ["All", "Government buildings", "Religious buildings", "Other"]
    searchController.searchBar.delegate = self
    
    // Setup the search footer
    tableView.tableFooterView = searchFooter
    
    if let splitViewController = splitViewController {
      let controllers = splitViewController.viewControllers
      detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
    }
  }
    
  override func viewWillAppear(_ animated: Bool) {
    if splitViewController!.isCollapsed {
      if let selectionIndexPath = self.tableView.indexPathForSelectedRow {
        self.tableView.deselectRow(at: selectionIndexPath, animated: animated)
      }
    }
    super.viewWillAppear(animated)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  // MARK: - Table View
  func numberOfSections(in tableView: UITableView) -> Int {
      return 1
  }
  
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let buildingCount = jsonArray?.count {
                if isFiltering() {
                    if let filteredCount = filteredCandies?.count {
                        searchFooter.setIsFilteringToShow(filteredItemCount: filteredCount, of: buildingCount)
                        return filteredCount
                    }
                }
                searchFooter.setNotFiltering()
                return buildingCount
        }
        return 0
    }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
      let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    let candy: [String: Any]
      if isFiltering() {
        if let filtered = filteredCandies?[indexPath.row] {
          candy = filtered
            cell.textLabel!.text = candy["nameEN"]! as? String
            cell.detailTextLabel!.text = candy["addressEN"]! as? String
        }
      } else {
          candy = (jsonArray?[indexPath.row])!
            cell.textLabel!.text = candy["nameEN"]! as? String
            cell.detailTextLabel!.text = candy["addressEN"]! as? String
      }
//      cell.textLabel!.text = candy["nameEN"]! as? String
//      cell.detailTextLabel!.text = candy["addressEN"]! as? String
      return cell
  }
    
  // MARK: - Private instance methods
  func searchBarIsEmpty() -> Bool {
      // Returns true if the text is empty or nil
      return searchController.searchBar.text?.isEmpty ?? true
  }
    
    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        filteredCandies = jsonArray?.filter({( candy : [String: Any]) -> Bool in
            let doesCategoryMatch = (scope == "All") || (candy["categoryEN"]! as? String == scope)
            
            if searchBarIsEmpty() {
                return doesCategoryMatch
            } else {
                let thing = candy["nameEN"]! as? String
                return doesCategoryMatch && thing!.lowercased().contains(searchText.lowercased())
            }
        })
        tableView.reloadData()
    }

    func isFiltering() -> Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && (!searchBarIsEmpty() || searchBarScopeIsFiltering)
    }
    
  // MARK: - Segues
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let candy: [String: Any]
        let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
        if isFiltering() {
            if let filtered = filteredCandies?[indexPath.row] {
                candy = filtered
                controller.detailCandy = candy
            }
        } else {
            candy = (jsonArray?[indexPath.row])!
            controller.detailCandy = candy
        }
//        let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
//        controller.detailCandy = candy
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
      }
    }
  }
}

extension MasterViewController: UISearchResultsUpdating {
    // MARK: - UISearchResultsUpdating Delegate
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        let scope = searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex]
        filterContentForSearchText(searchController.searchBar.text!, scope: scope)
    }
}

extension MasterViewController: UISearchBarDelegate {
    // MARK: - UISearchBar Delegate
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        filterContentForSearchText(searchBar.text!, scope: searchBar.scopeButtonTitles![selectedScope])
    }
}
