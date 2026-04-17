/// <p>Abstract base class for JavaScript runtime backends (Epic 12 / Story 12.1).</p>
/// <p>Callers (<class>IRISCouch.API.ViewHandler</class>,
/// <class>IRISCouch.API.ChangesHandler</class>,
/// <class>IRISCouch.Core.DocumentEngine</class>, etc.) MUST depend only on
/// this abstract type and NEVER on any concrete subclass. Concrete backends
/// (<class>IRISCouch.JSRuntime.None</class>,
/// <class>IRISCouch.JSRuntime.Subprocess</class>,
/// <class>IRISCouch.JSRuntime.Python</class>) are resolved via
/// <class>IRISCouch.JSRuntime.Factory</class>.</p>
///
/// <h3>Protocol reference</h3>
/// <p>Method shapes mirror the CouchDB <code>couchjs</code> line protocol:</p>
/// <ul>
/// <li><code>ExecuteMap(fn, doc)</code> -- emits <code>[key, value]</code> pairs
///     per document; see <code>sources/couchdb/share/server/views.js::mapDoc</code>.</li>
/// <li><code>ExecuteReduce(fn, keys, values, rereduce)</code> -- reduces
///     key/value pairs to a scalar; see
///     <code>sources/couchdb/share/server/views.js::runReduce</code>.</li>
/// <li><code>ExecuteValidateDocUpdate(fn, newDoc, oldDoc, userCtx, secObj)</code>
///     -- throws for rejection; see
///     <code>sources/couchdb/share/server/validate.js::validate</code>.</li>
/// <li><code>ExecuteFilter(fn, doc, req)</code> -- returns truthy per doc;
///     see <code>sources/couchdb/share/server/filter.js::filter</code>.</li>
/// </ul>
///
/// <p>Per <code>.claude/rules/iris-objectscript-basics.md::Abstract Methods</code>,
/// every abstract method MUST have an implementation body returning a valid
/// default value for its declared return type. Concrete subclasses override
/// these defaults.</p>
Class IRISCouch.JSRuntime.Sandbox Extends %RegisteredObject [ Abstract ]
{

/// <p>Report whether this backend can actually execute JavaScript.</p>
/// <p>Returns <code>0</code> for the None backend and for not-yet-implemented
/// stubs; returns <code>1</code> for fully functional backends. Callers may
/// branch on this to short-circuit past a backend call (e.g., skip
/// <code>validate_doc_update</code> invocation entirely when no runtime is
/// available) without relying on try/catch for control flow.</p>
/// @return %Boolean 1 if the backend executes JS, 0 otherwise
Method IsAvailable() As %Boolean [ Abstract ]
{
    Quit 0
}

/// <p>Execute a CouchDB map function against a single document.</p>
/// <p>Corresponds to the <code>mapDoc</code> protocol command: the function
/// calls <code>emit(key, value)</code> zero or more times; the runtime returns
/// the accumulated pairs as a <class>%DynamicArray</class> where each element
/// is a two-element array of the form <code>[key, value]</code>.</p>
/// @param pMapFn The JavaScript map function source (e.g., <code>"function(doc){emit(doc._id,1);}"</code>)
/// @param pDoc The target document as a <class>%DynamicObject</class>
/// @return %DynamicArray of <code>[key, value]</code> pairs; empty array if no emissions
Method ExecuteMap(pMapFn As %String, pDoc As %DynamicObject) As %DynamicArray [ Abstract ]
{
    Quit $$$NULLOREF
}

/// <p>Execute a CouchDB reduce function over collected keys/values.</p>
/// <p>Corresponds to the <code>reduce</code> / <code>rereduce</code> protocol
/// commands. Returns an envelope of the form
/// <code>{"ok": true, "value": &lt;scalar&gt;}</code> on success.</p>
/// @param pReduceFn The JavaScript reduce function source
/// @param pKeys A <class>%DynamicArray</class> of keys (may be null in rereduce mode)
/// @param pValues A <class>%DynamicArray</class> of values
/// @param pRereduce 1 if this is a rereduce pass over prior reductions, 0 otherwise
/// @return %DynamicObject envelope with the reduced value
Method ExecuteReduce(pReduceFn As %String, pKeys As %DynamicArray, pValues As %DynamicArray, pRereduce As %Boolean) As %DynamicObject [ Abstract ]
{
    Quit $$$NULLOREF
}

/// <p>Execute a <code>validate_doc_update</code> function for a write.</p>
/// <p>Argument order mirrors the couchjs protocol exactly:
/// <code>newDoc, oldDoc, userCtx, secObj</code>. The function approves by
/// returning normally and rejects by throwing (CouchDB maps the thrown value
/// to 401/403/<code>forbidden</code>). See
/// <code>sources/couchdb/share/server/validate.js</code>.</p>
/// <p>Concrete backends return <code>$$$OK</code> on approval and an error
/// <class>%Status</class> whose message carries the rejection reason on
/// rejection. The caller surfaces that message as the HTTP error reason.</p>
/// @param pValidateFn The JavaScript function source
/// @param pNewDoc The document being written
/// @param pOldDoc The prior document revision, or the empty object for creates
/// @param pUserCtx The user context <code>{name, roles, db}</code>
/// @param pSecObj The database _security document
/// @return %Status $$$OK on approval; error %Status on rejection
Method ExecuteValidateDocUpdate(pValidateFn As %String, pNewDoc As %DynamicObject, pOldDoc As %DynamicObject, pUserCtx As %DynamicObject, pSecObj As %DynamicObject) As %Status [ Abstract ]
{
    Quit $$$OK
}

/// <p>Execute a custom filter function against a single document.</p>
/// <p>Corresponds to <code>sources/couchdb/share/server/filter.js</code>:
/// the filter takes <code>(doc, req)</code> and returns truthy to include the
/// document in the filtered feed, falsy to exclude it.</p>
/// @param pFilterFn The JavaScript filter function source
/// @param pDoc The candidate document
/// @param pReq The request object (query string, headers, etc.)
/// @return %Boolean 1 to include, 0 to exclude
Method ExecuteFilter(pFilterFn As %String, pDoc As %DynamicObject, pReq As %DynamicObject) As %Boolean [ Abstract ]
{
    Quit 0
}

}
