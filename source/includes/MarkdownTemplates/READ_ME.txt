Markdown templates

NOTE: These templates are not meant to be comprehensive, but rather serve as an aid to get started more quickly.
In nearly all cases you will need to supplement/modify the markdown to some degree to accommodate the documentation being added.

---

Instructions for Adding Docs for a New Endpoint:

CAUTION: Pay close attention to the existing convention for upper and lower case monikers (file names, reference to partials, etc.), and follow suit.  Incorrect case may cause build breaks or rendering issues.

1) Create a new folder under includes/APIReference, and a new folder "Examples" within it.
2) Start with the main object overview section by copying "_entity.md.erb" into your folder, and "_entity.tmpl.erb" & "_object.tmpl.erb" into your Examples folder.  Rename the _entity* files as needed.
3) In each template file you've copied, search for all instances of curly braces ({}).  Replace the value within each of these, or carry out the instructions contained within.
4) Add any additional content needed, while referring to existing endpoint docs for guidance.
5) Carry out a similar process as above for Create, Retrieve, Update, and Delete.

NOTE: Be sure to update index.html.md with references to the new files.
