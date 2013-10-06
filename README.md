poro_repository
================

Store plain old ruby objects to the file system. You can store any object that
can be marshalled. The objects to be stored need not inherit from any library
base class, nor include any library module.

Usage Examples
--------------

A simple example

```ruby
class Contact
  attr_accessor :id, :name
end

contact = Contact.new
contact.id = 1
contact.name = "John Smith"

repo = PoroRepository.new("/repository/path")
repo.save_record contact

# ...

repo.load_record('Contact', 1).name #=> "John Smith"
```

Storing different entities separately

```ruby
class Contact
  attr_accessor :id, :name, :company
end

class Company
  attr_accessor :id, :name
end

xyz_company = Company.new
xyz_company.id = 1
xyz_company.name = "XYZ Company"

contact = Contact.new
contact.id = 1
contact.name = "John Smith"
contact.company = xyz_company

repo = PoroRepository.new("/repository/path")
repo.boundary :Contact, :@company # causes company record to save separately

repo.save_record contact

# ...

# company record stored separately, and can be loaded independently
loaded_company = repo.load_record 'Company', 1

loaded_contact = repo.load_record 'Contact', 1
loaded_contact.company == loaded_company #=> true
loaded_contact.company.equal?(loaded_company) #=> true ; same object
```

Caveats
-------

* No consideration has been given to concurrency. If you need concurrency, you
  should probably use something else.
* At least at this stage, it is only really suitable for storing hundreds of
  objects, not thousands or millions.
* It's still very incomplete and is missing most features required for it to
  be generally useful.
