//
//  MasterViewController.swift
//  SoF-MedList
//
//  Created by Pascal Pfiffner on 6/20/14.
//  Copyright (c) 2014 SMART Platforms. All rights reserved.
//

import UIKit
import SMART


class MasterViewController: UITableViewController
{
	var patient: Patient?
	var previousConnectButtonTitle: String?
    var previousSettingsButtonTitle: String?
	
	var detailViewController: DetailViewController? = nil
	var medications: [MedicationOrder] = []
	
	
	override func awakeFromNib() {
		super.awakeFromNib()
		if UIDevice.current.userInterfaceIdiom == .pad {
		    self.clearsSelectionOnViewWillAppear = false
		    self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		connectButtonTitle = nil
        settingsButtonTitle = nil
		
		if let split = self.splitViewController {
			detailViewController = (split.viewControllers.last as? UINavigationController)?.topViewController as? DetailViewController
		}
	}
	
	
	// MARK: - Custom UI
	
	var connectButtonTitle: String? {
		get { return navigationItem.leftBarButtonItem?.title }
		set {
			let btn = UIBarButtonItem(title: (newValue ?? "Connect"), style: .plain, target: self, action: #selector(MasterViewController.selectPatient(_:)))
			navigationItem.leftBarButtonItem = btn
			previousConnectButtonTitle = btn.title
		}
	}
	
    var settingsButtonTitle: String? {
        get { return navigationItem.leftBarButtonItem?.title }
        set {
            let btn = UIBarButtonItem(title: (newValue ?? "Settings"), style: .plain, target: self, action: #selector(MasterViewController.showSandboxActionSheetButtonTapped(sender:)))
            navigationItem.rightBarButtonItem = btn
        }
    }
	
	// MARK: - Patient Handling
	@IBAction
	func selectPatient(_ sender: AnyObject?) {
		if navigationItem.leftBarButtonItem === sender {
			let activity = UIActivityIndicatorView(activityIndicatorStyle: .gray)
			activity.isUserInteractionEnabled = false
			let button = UIButton(frame: activity.bounds)
			button.addSubview(activity)
			button.addConstraint(NSLayoutConstraint(item: activity, attribute: .centerX, relatedBy: .equal, toItem: button, attribute: .centerX, multiplier: 1.0, constant: 0.0))
			button.addConstraint(NSLayoutConstraint(item: activity, attribute: .centerY, relatedBy: .equal, toItem: button, attribute: .centerY, multiplier: 1.0, constant: 0.0))
			button.addTarget(self, action: #selector(MasterViewController.cancelPatientSelection), for: .touchUpInside)
			let barbutton = UIBarButtonItem(customView: button)
			navigationItem.leftBarButtonItem = barbutton
			activity.startAnimating()
		}
		
		let app = UIApplication.shared.delegate as! AppDelegate
		app.selectPatient { patient, error in
			self.patient = patient
			if let error = error {
				DispatchQueue.main.async() {
					if NSURLErrorDomain != error._domain || NSURLErrorCancelled != error._code {
						UIAlertView(title: "Patient Selection Failed", message: "\(error)", delegate: self, cancelButtonTitle: "OK").show()
					}
					self.connectButtonTitle = nil
                    self.settingsButtonTitle = nil
				}
			}
			else if let pat = patient {
				
				// fetch patient's medications
				app.findMeds(for: pat) { meds, error in
					DispatchQueue.main.async() {
						if let error = error {
							UIAlertView(title: "Error Fetching Meds", message: error.description, delegate: nil, cancelButtonTitle: "OK").show()
						}
						else {
							self.medications = meds ?? []
							self.tableView.reloadData()
						}
						
						// finally, change the "connect" button
						if (pat.name?.count ?? 0) > 0 && (pat.name![0].given?.count ?? 0) > 0 {
							self.connectButtonTitle = pat.name![0].given![0]
                            self.settingsButtonTitle = nil
						}
						else {
							self.connectButtonTitle = "Unnamed"
                            self.settingsButtonTitle = nil
						}
					}
				}
			}
			
			// no error and no patient: cancelled
			else {
				DispatchQueue.main.async() {
					self.connectButtonTitle = self.previousConnectButtonTitle
                    self.settingsButtonTitle = self.previousSettingsButtonTitle
				}
			}
		}
	}
	
	func cancelPatientSelection() {
		let app = UIApplication.shared.delegate as! AppDelegate
		app.cancelRecordSelection()
		
		connectButtonTitle = previousConnectButtonTitle
	}
	
	
	// MARK: - Medication Handling
	
	func medicationName(_ med: MedicationOrder) -> String {
		if let medname = med.medicationCodeableConcept?.coding?.first?.display {
			return medname
		}
//		if let medname = med.medicationReference?.resolved(Medication)?.product?... {
//			return medname
//		}
		if let html = med.text?.div {
			do {
				let stripTags = try NSRegularExpression(pattern: "(<[^>]+>\\s*)|(\\r?\\n)", options: .caseInsensitive)
				return stripTags.stringByReplacingMatches(in: html, options: [], range: NSMakeRange(0, html.characters.count), withTemplate: "")
			}
			catch {}
		}
		if let display = med.medicationReference?.display {
			return display
		}
		return "No medication and no narrative"
	}
	
	
	// MARK: - Segues
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "showDetail" {
		    let indexPath = self.tableView.indexPathForSelectedRow
			if nil != indexPath && indexPath!.row < medications.count {
				((segue.destination as! UINavigationController).topViewController as! DetailViewController).prescription = medications[indexPath!.row]
			}
		}
	}
	
	
	// MARK: - Table View
	
	override func numberOfSections(in: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return max(1, medications.count)
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as UITableViewCell
		
		if indexPath.row < medications.count {
			let med = medications[indexPath.row]
			cell.textLabel?.text = medicationName(med)
			cell.textLabel?.textColor = UIColor.black
			cell.isUserInteractionEnabled = true
		}
		else {
			cell.textLabel?.text = (nil == patient) ? "" : "(no medications)"
			cell.textLabel?.textColor = UIColor.gray
			cell.isUserInteractionEnabled = false
		}
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if UIDevice.current.userInterfaceIdiom == .pad {
		    self.detailViewController!.prescription = medications[indexPath.row]
		}
	}
    
    @IBAction func showSandboxActionSheetButtonTapped(sender: UIButton) {
        
        // Create the action sheet
        let myActionSheet = UIAlertController(title: "Sandbox Connector", message: "Which sandbox would you like to use?", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        // Smart Sandbox Button
        let smartSandboxAction = UIAlertAction(title: "SMART on FHIR", style: UIAlertActionStyle.default) { (action) in
            let app = UIApplication.shared.delegate as! AppDelegate;
            app.smart = app.smartSandbox;
            print("Using SMART on FHIR sandbox");
        }
        
        // HSPC Sandbox Button
        let hspcSandboxAction = UIAlertAction(title: "HSPC", style: UIAlertActionStyle.default) { (action) in
            let app = UIApplication.shared.delegate as! AppDelegate;
            app.smart = app.hspcSandbox;
            print("Using HSPC sandbox");
        }
        
        // cancel action button
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (action) in
            print("Cancel action button tapped")
        }
        
        // add action buttons to action sheet
        myActionSheet.addAction(smartSandboxAction)
        myActionSheet.addAction(hspcSandboxAction)
        myActionSheet.addAction(cancelAction)
        
        // present the action sheet
        self.present(myActionSheet, animated: true, completion: nil)
    }
}

