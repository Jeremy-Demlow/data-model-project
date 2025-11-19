"""
Generate fake data for Snowflake source tables.

This script generates realistic fake data using Faker library for all
source tables referenced in the ETL bulk loads.
"""

import sys
import os
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from faker import Faker
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import yaml
import logging
from typing import Dict, List
from snowflake.snowpark import Session
from datetime import date

# Import connection module
from utils.snowflake_connection import SnowflakeConnection

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DataGenerator:
    """Generate fake data for all source tables."""
    
    def __init__(self, config_path: str = None):
        """Initialize with configuration."""
        if config_path is None:
            config_path = project_root / "config.yaml"
        
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.fake = Faker()
        Faker.seed(42)  # For reproducibility
        np.random.seed(42)
        
        self.tenant_id = self.config['tenant']['default_tenant_id']
        self.row_counts = self.config['data_generation']['row_counts']
        self.date_config = self.config['data_generation']['date_ranges']
        self.distributions = self.config['data_generation']['distributions']
        
        # Parse dates
        self.start_date = datetime.strptime(self.date_config['start_date'], '%Y-%m-%d').date()
        self.end_date = datetime.strptime(self.date_config['end_date'], '%Y-%m-%d').date()
        
        # Storage for generated data
        self.data = {}
        
    def generate_all(self):
        """Generate all source tables in dependency order."""
        logger.info("Starting data generation...")
        
        # Phase 1: Lookup tables (no dependencies)
        logger.info("Phase 1: Generating lookup tables...")
        self.generate_business_units()
        self.generate_job_types()
        self.generate_customers()
        self.generate_employees()
        self.generate_locations()
        self.generate_gl_account_types()
        self.generate_gl_accounts()
        self.generate_materials()
        self.generate_equipment()
        self.generate_custom_field_types()
        
        # Phase 2: Service Agreement Templates and Locations
        logger.info("Phase 2: Generating service agreement templates...")
        self.generate_service_agreement_templates()
        
        # Phase 2b: Service Agreements (depends on customers, locations, templates)
        logger.info("Phase 2b: Generating service agreements...")
        self.generate_service_agreements()
        self.generate_service_agreement_locations()
        
        # Phase 3: Jobs (depends on customers, locations, business units, job types, service agreements)
        logger.info("Phase 3: Generating jobs...")
        self.generate_jobs()
        
        # Phase 4: Custom fields (depends on jobs, employees)
        logger.info("Phase 4: Generating custom fields...")
        self.generate_custom_fields()
        
        # Phase 5: Invoices (depends on jobs)
        logger.info("Phase 5: Generating invoices...")
        self.generate_invoices()
        
        # Phase 6: Invoice items (depends on invoices, GL accounts)
        logger.info("Phase 6: Generating invoice items...")
        self.generate_invoice_items()
        
        # Phase 7: Purchase orders and inventory (for PO costs)
        logger.info("Phase 7: Generating purchase orders and inventory...")
        self.generate_purchase_orders()
        
        # Phase 8: Inventory returns (for job returns)
        logger.info("Phase 8: Generating inventory returns...")
        self.generate_inventory_returns()
        
        # Phase 9: Labor/payroll data (for labor costs)
        logger.info("Phase 9: Generating labor and payroll data...")
        self.generate_technicians()
        self.generate_grosspay_items()
        self.generate_payroll_adjustments()
        
        # Phase 10: Service agreement visits (for SA measures)
        logger.info("Phase 10: Generating service agreement visits...")
        self.generate_service_agreement_visits()
        
        logger.info("Data generation complete!")
        
    def generate_business_units(self):
        """Generate business unit data."""
        logger.info(f"Generating {self.row_counts['business_unit']} business units...")
        
        bu_names = ['HVAC', 'Plumbing', 'Electrical', 'General Services', 
                    'Residential', 'Commercial', 'Industrial', 'Emergency Services',
                    'Maintenance', 'Installation']
        
        data = []
        for i in range(self.row_counts['business_unit']):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': bu_names[i % len(bu_names)] if i < len(bu_names) else f'Business Unit {i+1}',
                'ACTIVE': 1
            })
        
        self.data['businessunit'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} business units")
    
    def generate_job_types(self):
        """Generate job type data."""
        logger.info(f"Generating {self.row_counts['job_type']} job types...")
        
        job_types = ['Service Call', 'Installation', 'Maintenance', 'Repair', 
                     'Emergency', 'Inspection', 'Consultation', 'Warranty',
                     'Project', 'Retrofit', 'Upgrade', 'Replacement',
                     'Preventive Maintenance', 'Diagnostic', 'Estimate',
                     'Follow-up', 'Callback', 'Training', 'Audit', 'Other']
        
        data = []
        for i in range(self.row_counts['job_type']):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': job_types[i % len(job_types)] if i < len(job_types) else f'Job Type {i+1}',
                'ACTIVE': 1
            })
        
        self.data['jobtype'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} job types")
    
    def generate_customers(self):
        """Generate customer data."""
        logger.info(f"Generating {self.row_counts['customer']} customers...")
        
        data = []
        active_count = int(self.row_counts['customer'] * self.distributions['active_customer_pct'])
        
        for i in range(self.row_counts['customer']):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': self.fake.company(),
                'ACTIVE': 1 if i < active_count else 0
            })
        
        self.data['customer'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} customers ({active_count} active)")
    
    def generate_employees(self):
        """Generate employee data."""
        logger.info(f"Generating {self.row_counts['employee']} employees...")
        
        data = []
        for i in range(self.row_counts['employee']):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': self.fake.name(),
                'ACTIVE': 1
            })
        
        self.data['employee'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} employees")
    
    def generate_locations(self):
        """Generate location data."""
        logger.info(f"Generating {self.row_counts['location']} locations...")
        
        data = []
        for i in range(self.row_counts['location']):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': self.fake.address().replace('\n', ', ')
            })
        
        self.data['location'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} locations")
    
    def generate_gl_account_types(self):
        """Generate GL account types."""
        logger.info("Generating GL account types...")
        
        account_types = ['Income', 'Expense', 'Asset', 'Liability', 'Equity']
        
        data = []
        for i, name in enumerate(account_types):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': name,
                'ACTIVE': 1
            })
        
        self.data['generalledgeraccounttype'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} GL account types")
    
    def generate_gl_accounts(self):
        """Generate GL accounts."""
        logger.info(f"Generating {self.row_counts['gl_account']} GL accounts...")
        
        account_types_df = self.data['generalledgeraccounttype']
        
        data = []
        for i in range(self.row_counts['gl_account']):
            type_id = account_types_df.iloc[i % len(account_types_df)]['ID']
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'TYPE_ID': type_id,
                'NAME': f'Account {i+1:04d}',
                'ACTIVE': 1
            })
        
        self.data['generalledgeraccount'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} GL accounts")
    
    def generate_materials(self):
        """Generate material SKUs."""
        logger.info(f"Generating {self.row_counts['sku'] // 2} materials...")
        
        data = []
        for i in range(self.row_counts['sku'] // 2):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': f'Material-{i+1}',
                'ACTIVE': 1
            })
        
        self.data['material'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} materials")
    
    def generate_equipment(self):
        """Generate equipment SKUs."""
        logger.info(f"Generating {self.row_counts['sku'] // 2} equipment items...")
        
        data = []
        for i in range(self.row_counts['sku'] // 2):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': f'Equipment-{i+1}',
                'ACTIVE': 1
            })
        
        self.data['equipment'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} equipment items")
    
    def generate_custom_field_types(self):
        """Generate custom field types."""
        logger.info("Generating custom field types...")
        
        # ownertype values: Job = 4, Employee = 32
        data = [
            {
                'ID': 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': 'Salesperson',
                'OWNERTYPE': 4,  # Job owner type
                'ACTIVE': 1
            },
            {
                'ID': 2,
                '_TENANT_ID': self.tenant_id,
                'NAME': 'Commission Type',
                'OWNERTYPE': 32,  # Employee owner type
                'ACTIVE': 1
            },
            {
                'ID': 3,
                '_TENANT_ID': self.tenant_id,
                'NAME': 'Job Commission%',
                'OWNERTYPE': 32,
                'ACTIVE': 1
            },
            {
                'ID': 4,
                '_TENANT_ID': self.tenant_id,
                'NAME': 'SAYear1Commission%',
                'OWNERTYPE': 32,
                'ACTIVE': 1
            },
            {
                'ID': 5,
                '_TENANT_ID': self.tenant_id,
                'NAME': 'SAYear2Commission%',
                'OWNERTYPE': 32,
                'ACTIVE': 1
            },
            {
                'ID': 6,
                '_TENANT_ID': self.tenant_id,
                'NAME': 'SAYear3+Commission%',
                'OWNERTYPE': 32,
                'ACTIVE': 1
            }
        ]
        
        self.data['customfieldtype'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} custom field types")
    
    def generate_service_agreement_templates(self):
        """Generate service agreement templates."""
        logger.info("Generating service agreement templates...")
        
        template_names = ['Standard Maintenance', 'Premium Support', 'Basic Service', 
                         'Enterprise', 'Custom']
        
        data = []
        for i, name in enumerate(template_names):
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'NAME': name,
                'ACTIVE': 1
            })
        
        self.data['serviceagreementtemplate'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} service agreement templates")
    
    def generate_service_agreements(self):
        """Generate service agreements."""
        logger.info(f"Generating {self.row_counts['service_agreement']} service agreements...")
        
        customers = self.data['customer']
        locations = self.data['location']
        business_units = self.data['businessunit']
        employees = self.data['employee']
        templates = self.data['serviceagreementtemplate']
        
        data = []
        for i in range(self.row_counts['service_agreement']):
            customer = customers.iloc[i % len(customers)]
            location = locations.iloc[i % len(locations)]
            business_unit = business_units.iloc[i % len(business_units)]
            employee = employees.iloc[i % len(employees)]
            template = templates.iloc[i % len(templates)]
            
            start_date = self.fake.date_between(start_date=self.start_date, end_date=self.end_date)
            end_date = start_date + timedelta(days=365)  # 1 year agreements
            
            # Create renewal groups (some SAs are renewals)
            is_renewal = i > 0 and np.random.random() < 0.3  # 30% are renewals
            renewal_group_id = (i // 3) + 1 if is_renewal else i + 1
            
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'CUSTOMERID': customer['ID'],
                'BUSINESSUNITID': business_unit['ID'],
                'SOLDBYID': employee['ID'],
                'NAME': f'SA-{i+1:05d}',
                'TEMPLATEINSTANCE_ID': template['ID'],
                'STARTDATE': start_date,
                'ENDDATE': end_date,
                'RENEWALGROUPINITIALAGREEMENT_ID': renewal_group_id,
                'RENEWEDBY_ID': employee['ID'] if is_renewal else None,
                'STATUS': 3,  # Active
                'ACTIVE': 1
            })
        
        self.data['serviceagreement'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} service agreements")
    
    def generate_service_agreement_locations(self):
        """Generate service agreement location linkages."""
        logger.info("Generating service agreement locations...")
        
        service_agreements = self.data['serviceagreement']
        locations = self.data['location']
        
        data = []
        for i, sa in service_agreements.iterrows():
            # Each SA has 1-3 locations
            num_locations = np.random.randint(1, 4)
            for j in range(num_locations):
                location = locations.iloc[(i + j) % len(locations)]
                data.append({
                    'ID': len(data) + 1,
                    '_TENANT_ID': self.tenant_id,
                    'SERVICEAGREEMENT_ID': sa['ID'],
                    'LOCATIONID': location['ID'],
                    'ACTIVE': 1
                })
        
        self.data['serviceagreementlocation'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} service agreement locations")
    
    def generate_jobs(self):
        """Generate job data."""
        logger.info(f"Generating {self.row_counts['job']} jobs...")
        
        customers = self.data['customer']
        locations = self.data['location']
        business_units = self.data['businessunit']
        job_types = self.data['jobtype']
        service_agreements = self.data['serviceagreement']
        
        sa_job_count = int(self.row_counts['job'] * self.distributions['service_agreement_pct'])
        
        data = []
        for i in range(self.row_counts['job']):
            customer = customers.iloc[i % len(customers)]
            location = locations.iloc[i % len(locations)]
            business_unit = business_units.iloc[i % len(business_units)]
            job_type = job_types.iloc[i % len(job_types)]
            
            # Some jobs are SA visits
            service_agreement_id = None
            if i < sa_job_count:
                sa = service_agreements.iloc[i % len(service_agreements)]
                service_agreement_id = sa['ID']
            
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'CUSTOMER_ID': customer['ID'],
                'LOCATION_ID': location['ID'],
                'BUSINESSUNIT_ID': business_unit['ID'],
                'TYPE_ID': job_type['ID'],
                'SUMMARY': f'Job {i+1}: {self.fake.catch_phrase()}',
                'SERVICE_AGREEMENT_ID': service_agreement_id,
                'ACTIVE': 1
            })
        
        self.data['job'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} jobs ({sa_job_count} SA visits)")
    
    def generate_custom_fields(self):
        """Generate custom fields (salesperson assignments + employee commission rates)."""
        logger.info("Generating custom fields...")
        
        jobs = self.data['job']
        employees = self.data['employee']
        cft = self.data['customfieldtype']
        
        salesperson_type_id = cft[cft['NAME'] == 'Salesperson'].iloc[0]['ID']
        
        data = []
        cf_id = 1
        
        # 1. Job-level custom fields: Assign salesperson to 80% of jobs
        logger.info("  Creating job salesperson assignments...")
        job_count = int(len(jobs) * 0.8)
        
        for i in range(job_count):
            job = jobs.iloc[i]
            employee = employees.iloc[i % len(employees)]
            
            # Generate a proper timestamp (keep as datetime object for pandas)
            created_date = self.fake.date_time_between(start_date=self.start_date, end_date=self.end_date)
            
            data.append({
                'ID': cf_id,
                '_TENANT_ID': self.tenant_id,
                'OWNER_ID': job['ID'],
                'TYPE_ID': salesperson_type_id,
                'VALUE': employee['NAME'],
                'CREATEDON': created_date,  # Keep as datetime
                'ACTIVE': 1
            })
            cf_id += 1
        
        # 2. Employee-level custom fields: Commission rates for all employees
        logger.info("  Creating employee commission rate fields...")
        commission_field_types = {
            'Commission Type': ('0', 2),  # type_id = 2
            'Job Commission%': ('5.0', 3),
            'SAYear1Commission%': ('10.0', 4),
            'SAYear2Commission%': ('7.5', 5),
            'SAYear3+Commission%': ('5.0', 6)
        }
        
        for employee in employees.itertuples():
            for field_name, (default_value, type_id) in commission_field_types.items():
                # Randomize commission rates a bit for realism
                if field_name == 'Commission Type':
                    value = '0'
                elif 'Job' in field_name:
                    value = str(round(np.random.uniform(3.0, 7.0), 1))
                elif 'Year1' in field_name:
                    value = str(round(np.random.uniform(8.0, 12.0), 1))
                elif 'Year2' in field_name:
                    value = str(round(np.random.uniform(5.0, 10.0), 1))
                else:  # Year3+
                    value = str(round(np.random.uniform(3.0, 7.0), 1))
                
                # Generate a proper timestamp (keep as datetime object)
                created_date = self.fake.date_time_between(start_date=self.start_date, end_date=self.end_date)
                
                data.append({
                    'ID': cf_id,
                    '_TENANT_ID': self.tenant_id,
                    'OWNER_ID': employee.ID,
                    'TYPE_ID': type_id,
                    'VALUE': value,
                    'CREATEDON': created_date,  # Keep as datetime
                    'ACTIVE': 1
                })
                cf_id += 1
        
        df = pd.DataFrame(data)
        df['CREATEDON'] = pd.to_datetime(df['CREATEDON']).dt.strftime('%Y-%m-%d %H:%M:%S')
        self.data['customfield'] = df
        logger.info(f"  Created {len(data)} custom field assignments (jobs + employee commissions)")
    
    def generate_invoices(self):
        """Generate invoice data."""
        logger.info(f"Generating {self.row_counts['invoice']} invoices...")
        
        jobs = self.data['job']
        adjustment_count = int(self.row_counts['invoice'] * self.distributions['adjustment_invoice_pct'])
        
        data = []
        for i in range(self.row_counts['invoice']):
            job = jobs.iloc[i % len(jobs)]
            invoice_date = self.fake.date_between(start_date=self.start_date, end_date=self.end_date)
            
            # Some invoices are adjustments to previous invoices
            adjustment_to_id = None
            if i >= (self.row_counts['invoice'] - adjustment_count) and i > 0:
                adjustment_to_id = i  # Adjust previous invoice
            
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'JOB_ID': job['ID'],
                'INVOICEDON': invoice_date,  # Keep as date object
                'MODIFIEDON': invoice_date,
                'TRANS_NUMBER': f'INV-{i+1:06d}',
                'STATUS': 2,  # Posted
                'ADJUSTMENTTO_ID': adjustment_to_id,
                'ACTIVE': 1
            })
        
        self.data['invoice'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} invoices ({adjustment_count} adjustments)")
    
    def generate_invoice_items(self):
        """Generate invoice item data."""
        logger.info(f"Generating {self.row_counts['invoice_item']} invoice items...")
        
        invoices = self.data['invoice']
        gl_accounts = self.data['generalledgeraccount']
        
        # Average items per invoice
        avg_items_per_invoice = self.row_counts['invoice_item'] / len(invoices)
        
        data = []
        item_id = 1
        
        for i, invoice in invoices.iterrows():
            # Random number of items per invoice (Poisson distribution)
            num_items = max(1, int(np.random.poisson(avg_items_per_invoice)))
            
            for j in range(num_items):
                if item_id > self.row_counts['invoice_item']:
                    break
                
                gl_account = gl_accounts.iloc[(item_id - 1) % len(gl_accounts)]
                
                # Generate realistic amounts
                amount = round(np.random.lognormal(5, 1), 2)  # Mean ~$150, varies widely
                
                # Determine if this is a material/equipment item or labor/other
                is_sku_item = np.random.random() < 0.6  # 60% are SKU items
                
                if is_sku_item:
                    # Randomly choose material (type 1) or equipment (type 2)
                    sku_type = np.random.choice([1, 2])
                    if sku_type == 1:
                        materials = self.data['material']
                        sku_id = materials.iloc[item_id % len(materials)]['ID']
                    else:
                        equipment = self.data['equipment']
                        sku_id = equipment.iloc[item_id % len(equipment)]['ID']
                else:
                    sku_type = None
                    sku_id = None
                
                # PO items (10% are from purchase orders)
                is_po_item = np.random.random() < 0.10
                
                # Quantity for SKU items
                quantity = np.random.randint(1, 10) if sku_type else 1
                
                data.append({
                    'ID': item_id,
                    '_TENANT_ID': self.tenant_id,
                    'INVOICE_ID': invoice['ID'],
                    'GENERALLEDGERACCOUNT_ID': gl_account['ID'],
                    'DESCRIPTION': f'Invoice item {item_id}',
                    'QUANTITY': quantity,
                    'TOTAL': amount,
                    'TOTALCOST': amount * 0.7,  # Cost is typically 70% of total
                    'SKUREFERENCE_SKUTYPE': sku_type,
                    'SKUREFERENCE_SKUID': sku_id,
                    'PROCUREMENTSOURCE_PURCHASEORDERITEMID': (item_id * 1000) if is_po_item else None,
                    'ACTIVE': 1
                })
                
                item_id += 1
            
            if item_id > self.row_counts['invoice_item']:
                break
        
        self.data['invoiceitem'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} invoice items")
    
    def generate_purchase_orders(self):
        """Generate purchase order data for PO costs."""
        logger.info("Generating purchase orders...")
        
        invoices = self.data['invoice']
        
        # 30% of invoices have purchase orders
        po_invoice_count = int(len(invoices) * 0.3)
        
        data = []
        for i in range(po_invoice_count):
            invoice = invoices.iloc[i]
            # 1-3 POs per invoice
            num_pos = np.random.randint(1, 4)
            for j in range(num_pos):
                data.append({
                    'ID': len(data) + 1,
                    '_TENANT_ID': self.tenant_id,
                    'INVOICE_ID': invoice['ID'],
                    'AMOUNT': round(np.random.uniform(100, 1000), 2),
                    'MODIFIEDON': invoice['INVOICEDON'],
                    'ACTIVE': 1
                })
        
        self.data['purchaseorder'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} purchase orders")
        
        # Inventory bills (billed POs)
        bill_data = []
        for po in data[:len(data)//2]:  # 50% are billed
            bill_data.append({
                'ID': len(bill_data) + 1,
                '_TENANT_ID': self.tenant_id,
                'PURCHASEORDER_ID': po['ID'],
                'TOTAL': po['AMOUNT'],
                'ACTIVE': 1
            })
        
        self.data['inventorybill'] = pd.DataFrame(bill_data)
        logger.info(f"  Created {len(bill_data)} inventory bills")
        
        # Inventory shipments
        shipment_data = []
        for po in data[:len(data)//3]:  # 33% have shipments
            shipment_data.append({
                'ID': len(shipment_data) + 1,
                '_TENANT_ID': self.tenant_id,
                'PURCHASEORDER_ID': po['ID'],
                'BILL_ID': len(shipment_data) + 1 if np.random.random() < 0.5 else None,
                'ACTIVE': 1
            })
        
        self.data['inventoryshipment'] = pd.DataFrame(shipment_data)
        logger.info(f"  Created {len(shipment_data)} inventory shipments")
    
    def generate_inventory_returns(self):
        """Generate inventory return data for job returns."""
        logger.info("Generating inventory returns...")
        
        invoices = self.data['invoice']
        materials = self.data['material']
        
        # 10% of invoices have returns
        return_count = int(len(invoices) * 0.10)
        
        data = []
        for i in range(return_count):
            invoice = invoices.iloc[i]
            material = materials.iloc[i % len(materials)]
            
            return_date = invoice['INVOICEDON'] + timedelta(days=np.random.randint(1, 30))
            amount = round(np.random.uniform(10, 200), 2)
            
            data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'INVOICE_ID': invoice['ID'],
                'JOB_ID': invoice['JOB_ID'],
                'MATERIAL_ID': material['ID'],
                'AMOUNT': amount,
                'CREDIT': amount,  # Same as amount
                'CREATEDON': self.fake.date_time_between(start_date=self.start_date, end_date=self.end_date),
                'DATERETURNED': return_date,
                'ACTIVE': 1
            })
        
        df = pd.DataFrame(data)
        df['CREATEDON'] = pd.to_datetime(df['CREATEDON']).dt.strftime('%Y-%m-%d %H:%M:%S')
        self.data['inventoryreturn'] = df
        logger.info(f"  Created {len(data)} inventory returns")
    
    def generate_technicians(self):
        """Generate technician records with burden rates."""
        logger.info("Generating technicians...")
        
        employees = self.data['employee']
        
        # Use employees as technicians
        data = []
        for emp in employees.itertuples():
            data.append({
                'ID': emp.ID,
                '_TENANT_ID': self.tenant_id,
                'BURDENRATE': round(np.random.uniform(15, 35), 2),  # Burden rate per hour
                'ACTIVE': 1
            })
        
        self.data['technician'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} technicians")
    
    def generate_grosspay_items(self):
        """Generate grosspay items for labor costs."""
        logger.info("Generating grosspay items...")
        
        invoices = self.data['invoice']
        employees = self.data['employee']
        
        # Generate grosspayitem (80% of invoices have labor)
        grosspay_data = []
        for i, invoice in invoices.iterrows():
            if np.random.random() < 0.8:
                # 1-2 grosspay items per invoice
                for _ in range(np.random.randint(1, 3)):
                    grosspay_data.append({
                        'ID': len(grosspay_data) + 1,
                        '_TENANT_ID': self.tenant_id,
                        'JOB_ID': invoice['JOB_ID'],
                        'INVOICE_ID': invoice['ID'],
                        'TECHNICIAN_ID': employees.iloc[i % len(employees)]['ID'],
                        'AMOUNT': round(np.random.uniform(100, 500), 2),
                        'PAIDDURATIONHOURS': round(np.random.uniform(2, 16), 2),
                        'GROSSPAYITEMTYPE': np.random.choice([1, 2, 3, 4]),  # 1,3=piecework, 2,4=regular
                        'BURDENCOSTAMOUNT': round(np.random.uniform(20, 100), 2),
                        '_RECORD_UPDATED_TS_UTC': self.fake.date_time_between(start_date=self.start_date, end_date=self.end_date),
                        'ACTIVE': 1
                    })
        
        df = pd.DataFrame(grosspay_data)
        # Convert timestamp to string for Snowflake auto-parse
        df['_RECORD_UPDATED_TS_UTC'] = pd.to_datetime(df['_RECORD_UPDATED_TS_UTC']).dt.strftime('%Y-%m-%d %H:%M:%S')
        self.data['grosspayitem'] = df
        logger.info(f"  Created {len(grosspay_data)} grosspay items")
        
        # Generate employeegrosspayitem (smaller set)
        emp_grosspay_data = []
        for i in range(len(invoices) // 4):  # 25% have employee grosspay
            invoice = invoices.iloc[i]
            emp_grosspay_data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'JOB_ID': invoice['JOB_ID'],
                'INVOICE_ID': invoice['ID'],
                'EMPLOYEE_ID': employees.iloc[i % len(employees)]['ID'],
                'AMOUNT': round(np.random.uniform(100, 500), 2),
                'PAIDDURATIONHOURS': round(np.random.uniform(2, 16), 2),
                'GROSSPAYITEMTYPE': np.random.choice([1, 2, 3, 4]),
                '_RECORD_UPDATED_TS_UTC': self.fake.date_time_between(start_date=self.start_date, end_date=self.end_date),
                'ACTIVE': 1
            })
        
        df = pd.DataFrame(emp_grosspay_data)
        df['_RECORD_UPDATED_TS_UTC'] = pd.to_datetime(df['_RECORD_UPDATED_TS_UTC']).dt.strftime('%Y-%m-%d %H:%M:%S')
        self.data['employeegrosspayitem'] = df
        logger.info(f"  Created {len(emp_grosspay_data)} employee grosspay items")
    
    def generate_payroll_adjustments(self):
        """Generate payroll adjustments."""
        logger.info("Generating payroll adjustments...")
        
        invoices = self.data['invoice']
        employees = self.data['employee']
        
        # 10% of invoices have payroll adjustments
        pa_data = []
        for i in range(len(invoices) // 10):
            invoice = invoices.iloc[i]
            pa_data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'INVOICE_ID': invoice['ID'],
                'AMOUNT': round(np.random.uniform(-100, 100), 2),
                '_RECORD_UPDATED_TS_UTC': self.fake.date_time_between(start_date=self.start_date, end_date=self.end_date),
                'ACTIVE': 1
            })
        
        df = pd.DataFrame(pa_data)
        df['_RECORD_UPDATED_TS_UTC'] = pd.to_datetime(df['_RECORD_UPDATED_TS_UTC']).dt.strftime('%Y-%m-%d %H:%M:%S')
        self.data['payrolladjustment'] = df
        logger.info(f"  Created {len(pa_data)} payroll adjustments")
        
        # Employee payroll adjustments
        epa_data = []
        for i in range(len(invoices) // 20):
            invoice = invoices.iloc[i]
            epa_data.append({
                'ID': i + 1,
                '_TENANT_ID': self.tenant_id,
                'INVOICE_ID': invoice['ID'],
                'EMPLOYEE_ID': employees.iloc[i % len(employees)]['ID'],
                'AMOUNT': round(np.random.uniform(-100, 100), 2),
                '_RECORD_UPDATED_TS_UTC': self.fake.date_time_between(start_date=self.start_date, end_date=self.end_date),
                'ACTIVE': 1
            })
        
        df = pd.DataFrame(epa_data)
        df['_RECORD_UPDATED_TS_UTC'] = pd.to_datetime(df['_RECORD_UPDATED_TS_UTC']).dt.strftime('%Y-%m-%d %H:%M:%S')
        self.data['employeepayrolladjustment'] = df
        logger.info(f"  Created {len(epa_data)} employee payroll adjustments")
    
    def generate_service_agreement_visits(self):
        """Generate service agreement visit linkages."""
        logger.info("Generating service agreement visits...")
        
        service_agreements = self.data['serviceagreement']
        sa_locations = self.data['serviceagreementlocation']
        jobs = self.data['job']
        
        # Find SA visit jobs (those with service_agreement_id)
        sa_visit_jobs = jobs[jobs['SERVICE_AGREEMENT_ID'].notna()]
        
        data = []
        for i, job in sa_visit_jobs.iterrows():
            # Link to a service agreement location
            sa_id = int(job['SERVICE_AGREEMENT_ID'])
            matching_locs = sa_locations[sa_locations['SERVICEAGREEMENT_ID'] == sa_id]
            if len(matching_locs) > 0:
                sal = matching_locs.iloc[0]
                data.append({
                    'ID': len(data) + 1,
                    '_TENANT_ID': self.tenant_id,
                    'SERVICEAGREEMENTLOCATION_ID': sal['ID'],
                    'JOBID': job['ID'],
                    'ACTIVE': 1
                })
        
        self.data['serviceagreementvisit'] = pd.DataFrame(data)
        logger.info(f"  Created {len(data)} service agreement visits")
    
    def upload_to_snowflake(self):
        """Upload all generated data to Snowflake."""
        logger.info("Connecting to Snowflake...")
        
        # Connect using SnowflakeConnection class
        conn = SnowflakeConnection.from_snow_cli(
            connection_name=self.config['snowflake']['connection_name']
        )
        
        source_db = self.config['databases']['source']['name']
        source_schema = self.config['databases']['source']['schema']
        
        # Set database and schema context
        conn.execute(f"USE DATABASE {source_db}")
        conn.execute(f"USE SCHEMA {source_schema}")
        
        logger.info(f"Uploading data to {source_db}.{source_schema}...")
        
        # Tables with timestamp columns that need pre-created schemas
        timestamp_tables = {
            'grosspayitem', 'employeegrosspayitem', 
            'payrolladjustment', 'employeepayrolladjustment',
            'customfield', 'inventoryreturn'
        }
        
        # Upload each table
        for table_name, df in self.data.items():
            logger.info(f"  Uploading {table_name} ({len(df)} rows)...")
            
            # Uppercase column names
            df_upload = df.copy()
            df_upload.columns = df_upload.columns.str.upper()
            
            # For tables with timestamps, convert datetime64 columns to strings
            # Snowflake will auto-parse them correctly
            if table_name.lower() in timestamp_tables:
                for col in df_upload.columns:
                    if df_upload[col].dtype == 'datetime64[ns]':
                        # Convert to ISO format string
                        df_upload[col] = df_upload[col].dt.strftime('%Y-%m-%d %H:%M:%S.%f')
            
            # Use auto_create_table=False for tables with timestamps
            auto_create = table_name.lower() not in timestamp_tables
            
            # Use write_pandas
            conn.session.write_pandas(
                df=df_upload,
                table_name=table_name.upper(),
                auto_create_table=auto_create,
                overwrite=True
            )
            
            logger.info(f"    ✓ Successfully uploaded {table_name}")
        
        logger.info("All data uploaded successfully!")
        conn.close()


def main():
    """Main execution function."""
    try:
        generator = DataGenerator()
        generator.generate_all()
        generator.upload_to_snowflake()
        logger.info("Data generation and upload complete!")
        return 0
    except Exception as e:
        logger.error(f"Error during data generation: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())

