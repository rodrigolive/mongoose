function QueryTab( class_name ){
    this.class_name = class_name;
    this.id = explorer.query_tabs.length > 0 ? explorer.query_tabs[explorer.query_tabs.length-1].id + 1 : 0;
    this.chain = new Array;
    this.mode = 'edit';
    this.page = 0;
    this.make_name = function(){
        if( this.chain.length < 2 ){
            return this.class_name;
        }
        return this.chain[this.chain.length-1].name() + ' @ ' + this.class_name;
    };
    this.next_page = function(){
        this.page++;
        explorer.pages.query_tab( explorer.get_current_query_tab().id );
    };
    this.previous_page = function(){
        this.page--;
        explorer.pages.query_tab( explorer.get_current_query_tab().id );
    };
    this.edit_link = function( link_id ){
        this.selected_link = link_id;
        explorer.pages.edit_link( link_id );
    };
    this.get_link = function( link_id ){
        for (var i = 0; i < this.chain.length; i++) { if( this.chain[i].id == link_id ){ return this.chain[i]; } }; return {};
    };
    this.first_link = function(){
        var link = new Link( {type: 'root', parent: this } );
        link.class_name = this.class_name;
        this.chain.push( link );
        this.edit_link( link.id );
    };
    this.delete_last_link = function(){
        if( this.chain.length == 1 ){ return; }
        this.chain.pop();
        explorer.pages.query_tab( explorer.get_current_query_tab().id );
        this.edit_link(this.chain[this.chain.length-1].id);
    };
    this.add_links = function( links ){
        if( links === undefined ){ return; }
        var link;
        for (var i = 0; i < links.length; i++) {
            link = links[i];
            //finish link creation
            link.parent = this;
            link.make_id(this);
            this.chain.push( link );
            link.get_class();
            this.selected_link = link.id;
        }
    };
    this.add_link_for_method = function( method_name ){
        var link = new Link( { type: 'method', parent: this });
        link.method = this.find_method( method_name );
        this.chain.push( link );
        link.get_class();
        explorer.pages.query_tab( explorer.get_current_query_tab().id );
        this.edit_link( link.id );
    };
    this.find_method = function( method_name ){
        for (var i = 0; i < methods.length; i++) { if( methods[i].name == method_name ){ return methods[i]; } }; return '';
    };
    this.add_link_for_attribute = function( attribute_name, constraint ){
        var link = new Link( {type: 'attribute', parent: this} );
        link.attribute_name = attribute_name;
        link.constraint = constraint;
        this.chain.push( link );
        link.get_class();
        explorer.pages.query_tab( explorer.get_current_query_tab().id );
        this.edit_link( link.id );
    };
    this.make_code = function(){
        return this.make_code_up_to(this.chain[this.chain.length-1].id, 0);
    };
    this.make_safe_code = function(){
        return this.make_code_up_to(this.chain[this.chain.length-1].id, 1);
    };
    this.make_code_up_to = function( id_link, safe ){
        var codes = [];
        for (var i = 0; i < this.chain.length; i++) {
            if( safe == 1 && this.chain[i].type == 'method' && /(delete|update|remove|all)/.test(this.chain[i].method.name) ){ continue; }
            codes.push(this.chain[i].get_code());
            if( this.chain[i].id == id_link ){ break; }
        }
        return codes.join('->');
    };
}

function Link( params ){
    if( params !== undefined ){ for ( var prop in params ){ this[prop] = params[prop]; } }
    if( params.parameters === undefined ){this.parameters = { }; }
    this.make_id = function( parent ){
        this.id = parent.chain.length > 0 ? parent.chain[parent.chain.length-1].id + 1 : 0;
    };
    if( this.parent !== undefined ){
        this.make_id( this.parent );
    }
    this.get_class = function( ){
        var follower = this.follower();
        if( this.type == 'root' ){
            this.class_name = this.parent.class_name; return this.class_name;
        }
        if( follower.type == 'root' ){
            this.class_name = this.parent.class_name; return this.class_name;
        }
        if( this.type == 'method' ){
            if( follower.type == 'method' && ( follower.method.returns == 'resultset' || follower.method.returns == 'document' ) ){
                this.class_name = follower.class_name; return this.class_name;
            }
            if( follower.type == 'attribute' ){
                this.class_name = follower.class_name;
            }
        }
        if( this.type == 'attribute' ){
            if( this.isa() == 'join' ){
                this.class_name = this.constraint.match(/Mongoose::Join::Relational\[(.*?)\]/)[1];
            }
            if( this.isa() == 'document' ){
                this.class_name = this.constraint;
            }
        }
        return '';
    };
    this.name = function() {
        if( this.type == 'root' ){ return this.parent.class_name; }
        if( this.type == 'method' ){ return this.method.name; }
        if( this.type == 'attribute' ){ return this.attribute_name; }
        return '';
    };
    this.follower = function( ){
        if( this.position() == 0 ){ return 0; };
        return this.parent.chain[this.position()-1];
    };
    this.selected = function( ){
        return this.parent.selected_link == this.id ? 1 : 0;
    };
    this.can_method = function( method ){
        var position = this.position();
        if( this.type == 'root' ){ return 1; }
        if( this.type == 'method' ){ for (var i = 0; i < method.works_on.length; i++) { if( this.method.returns == method.works_on[i] ){ return 1; } } }
        if( this.type == 'attribute' ){
            if( this.isa() == 'join' ){
                for (var i = 0; i < method.works_on.length; i++) { if( 'join' == method.works_on[i] ){ return 1; } }
            }
            if( this.isa() == 'document' ){
                for (var i = 0; i < method.works_on.length; i++) { if( 'document' == method.works_on[i] ){ return 1; } }
            }
        }
        return 0;
    };
    this.position = function(){
        for (var i = 0; i < this.parent.chain.length; i++) { if( this.parent.chain[i].id == this.id ){ return i; } }; return 0;
    };
    this.isa = function(){
        if( /(Mongoose::Join)/.test( this.constraint ) ){ return 'join'; }
        if( ! /(Int|Num|Str|DateTime|MongoDB::OID|Mongoose::Join)/.test( this.constraint ) ){ return 'document'; }
        return 'value';
    };
    this.format_parameters = function(){
        var to_join = [];
        if( this.method.parameters !== undefined ){
            for (var i = 0; i < this.method.parameters.length ; i++) {
                var param = this.parameters[this.method.parameters[i].name];
                var type = this.method.parameters[i].type;
                if( param === undefined || param == '' ){
                    to_join.push( '{}' );
                }else{
                    if( type == 'hash'){
                        if( /^\s*\{.*/.test(param) ){
                            to_join.push( param );
                        }else{
                            to_join.push( '{' + param + '}' );
                        }
                    }else{
                        to_join.push( param );
                    }
                }
            }
        }
        for (var i =  to_join.length-1; i >= 0; i--) {
            if( to_join[i] == '{}' ){
                to_join.pop();
            }else{
                break;
            }
        }
        if( to_join.length > 0 ){
            return '(' + to_join.join(', ') + ')';
        }else{
            return '';
        }
    };
    this.get_code = function(){
        if( this.type == 'root' ){ return this.parent.class_name; }
        if( this.type == 'method' ){ return this.method.name + this.format_parameters(); }
        if( this.type == 'attribute' ){ return this.attribute_name; }
        return '';
    };
}

function Method(hash){
    for ( var prop in hash ){
        this[prop] = hash[prop];
    }
    this.return_name = { resultset: 'a Resulset', document: 'a Document', nothing: 'nothing', number: 'a Number', array: 'an Array', cursor: 'a Cursor' };
    this.returns_name = function(){
        return this.return_name[this.returns];
    };
}
var methods = [
    new Method({name: 'find', parameters: [{name:'query',type:'hash'},{name:'attributes',type:'hash'}], returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'search', parameters: [{name:'query',type:'hash'},{name:'attributes',type:'hash'}],returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'query',parameters: [{name:'query',type:'hash'},{name:'attributes',type:'hash'}],returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'resultset',returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'find_one', parameters: [{name:'query',type:'hash'},{name:'fields',type:'hash'}], returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'first',returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'find_or_new', parameters: [{name:'values',type:'hash'},{name:'attributes',type:'hash'}], returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'find_or_create', parameters: [{name:'values',type:'hash'},{name:'attributes',type:'hash'}], returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'update', parameters: [{name:'modification',type:'hash'},{name:'options',type:'hash'}], returns: 'document', works_on: ['root','resultset','join','document']}),
    new Method({name: 'update_or_create',parameters: [{name:'values',type:'hash'},{name:'modification',type:'hash'},{name:'attributes',type:'hash'}],returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'update_or_new',parameters: [{name:'values',type:'hash'},{name:'modification',type:'hash'},{name:'attributes',type:'hash'}],returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'delete',returns: 'nothing', works_on: ['root','resultset','join','document']}),
    new Method({name: 'remove',returns: 'nothing', works_on: ['root','resultset','join','document']}),
    new Method({name: 'next',returns: 'document', works_on: ['root','resultset','cursor']}),
    new Method({name: 'count',returns: 'number', works_on: ['root','resultset','join']}),
    new Method({name: 'all',returns: 'array', works_on: ['root','resultset','join']}),
    new Method({name: 'cursor',returns: 'cursor', works_on: ['root','resultset','join']}),
    new Method({name: 'new_result',parameters: [{name:'values',type:'hash'}],returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'create',parameters: [{name:'values',type:'hash'}],returns: 'document', works_on: ['root','resultset','join']}),
    new Method({name: 'skip',parameters: [{name:'number',type:'number'}],returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'limit',parameters: [{name:'number',type:'number'}],returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'sort_by',parameters: [{name:'fields',type:'hash'}],returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'fields',parameters: [{name:'fields',type:'hash'}],returns: 'resultset', works_on: ['root','resultset','join']}),
    new Method({name: 'insert',returns: 'document', works_on: ['document']})
];

//explorer object
var explorer = {
    query_tabs: new Array,
    current_query_tab: 0,
    pages: {
        explore: function( ){
            explorer.list_collections('explore');
            $('#nav li a').removeClass('active');
            $('#nav_explore').addClass('active');
        },
        query: function( ){
            explorer.list_collections('query');
            $('#nav li a').removeClass('active');
            $('#nav_query').addClass('active');
        },
        header: function( ){
            explorer.ajax_wait("#header_h2");
            $.ajax({ url: '/eval/', dataType: 'json', data: { code: '$db->_connection' }, success: function(data){
                $("#header h2").empty();
                $("#header_tpl").tmpl(data).appendTo("#header h2");
            } });
        },
        explore_class: function( class_name ){
            explorer.ajax_wait("#content");
            $.ajax({ url: '/eval/', dataType: 'json', data: { code: 'return { collection => ' + class_name + '->collection->full_name, class_name => "' + class_name + '", attributes => [map { {name => $_->name, constraint => $_->type_constraint->name } } ' + class_name + '->new->meta->get_all_attributes] }' }, success: function(data){
                $("#content").empty();
                $("#explore_class_tpl").tmpl(data).appendTo("#content");
            } });
        },
        query_class: function( class_name, links ){
            var query_tab = new QueryTab( class_name );
            explorer.query_tabs.push( query_tab );
            query_tab.first_link();
            query_tab.add_links(links);
            explorer.pages.query_tab(query_tab.id);
        },
        query_tab: function( id ){
            explorer.current_query_tab = id;
            explorer.refresh_query_tabs();
            var class_name = explorer.get_current_query_tab().class_name;
            explorer.ajax_wait("#content");
            $.ajax({ url: '/eval/', dataType: 'json', data: { code: 'return { collection => ' + class_name + '->collection->full_name, class_name => "' + class_name + '", attributes => [map { {name => $_->name, constraint => $_->type_constraint->name } } ' + class_name + '->new->meta->get_all_attributes] }' }, success: function(data){
                $("#content").empty();
                $("#query_class_tpl").tmpl(data).appendTo("#content");
                explorer.pages.query_chain();
                if( explorer.get_current_query_tab().mode == 'edit' ){
                    explorer.get_current_query_tab().edit_link( explorer.get_current_query_tab().selected_link );
                }else{
                    var code = explorer.get_current_query_tab().make_code();
                    explorer.ajax_wait("#query_results");
                    $.ajax({ url: '/eval_query/', dataType: 'json', data: { code: code, expand: 1, skip: explorer.get_current_query_tab().page * 10, limit: 10 }, success: function(data){
                        $("#query_results").empty();
                        data.expand = 1;
                        data.query_tab = explorer.get_current_query_tab();
                        $("#query_result_preview_tpl").tmpl(data).appendTo("#query_results");
                        sh_highlightDocument();
                    } });
                }
            } });
        },
        query_chain: function(){
            $("#query_chain").empty();
            $("#query_chain_tpl").tmpl({query_tab: explorer.get_current_query_tab()}).appendTo("#query_chain");
        },
        edit_link: function( link_id ) {
            explorer.get_current_query_tab().mode = 'edit'; //set back to edit
            var link = explorer.get_current_query_tab().get_link(link_id);
            $("#edit_link").empty();
            $("#edit_link_tpl").tmpl({link: link, methods: methods }).appendTo("#edit_link");
            explorer.pages.update_query( link.id );
            var class_name = link.class_name;
            if( ( link.type == 'method' && link.method.returns == 'document' ) || ( link.type == 'attribute' && link.isa() == 'document' ) ){
                explorer.ajax_wait("#attributes_to_add");
                $.ajax({ url: '/eval/', dataType: 'json', data: { code: 'return { collection => ' + class_name + '->collection->full_name, class_name => "' + class_name + '", attributes => [map { {name => $_->name, constraint => $_->type_constraint->name } } ' + class_name + '->new->meta->get_all_attributes] }' }, success: function(data){
                    $("#attributes_to_add").empty();
                    $("#attributes_to_add_tpl").tmpl(data).appendTo("#attributes_to_add");
                } });
            }
        },
        link_perl_code: function( link_id ){
            var link = explorer.get_current_query_tab().get_link(link_id);
            $("#link_perl_code").empty();
            $("#link_perl_code_tpl").tmpl({link: link}).appendTo("#link_perl_code");
            sh_highlightDocument();
        },
        update_query: function( id_link ){
            explorer.pages.query_chain();
            explorer.pages.link_perl_code( id_link );
            explorer.pages.query_result_preview( id_link );
        },
        query_result_preview: function( id_link ){
            var code = explorer.get_current_query_tab().make_code_up_to( id_link, 1 ); //safe
            explorer.ajax_wait("#query_result_preview");
            $.ajax({ url: '/eval_query/', dataType: 'json', data: { code: code, expand: 0 }, success: function(data){
                $("#query_result_preview").empty();
                data.expand = 0;
                $("#query_result_preview_tpl").tmpl(data).appendTo("#query_result_preview");
                sh_highlightDocument();
            } });
        },
        edit_query: function(){
            explorer.get_current_query_tab().mode = 'edit';
            explorer.pages.query_tab( explorer.current_query_tab );
        },
        run_query: function(){
            explorer.get_current_query_tab().mode = 'run';
            explorer.pages.query_tab( explorer.current_query_tab );
        },
        query_join: function( class_name, id, attribute_name, attribute_constraint ){
            explorer.pages.query_class(class_name, [
                new Link({
                    type: "method",
                    method: explorer.get_current_query_tab().find_method("find_one"),
                    parameters: { query: "\"_id\" => MongoDB::OID->new(value => \"" + id + "\")"}
                }),
                new Link({
                    type: "attribute",
                    attribute_name: attribute_name,
                    constraint: attribute_constraint
                })
            ]);
        },
        query_document: function( class_name, id ){
            explorer.pages.query_class(class_name, [
                new Link({
                    type: "method",
                    method: explorer.get_current_query_tab().find_method("find_one"),
                    parameters: { query: "\"_id\" => MongoDB::OID->new(value => \"" + id + "\")"}
                })
            ]);
        }
    },
    get_current_query_tab: function(){
        for (var i = 0; i < explorer.query_tabs.length; i++) {
            if( explorer.query_tabs[i].id == explorer.current_query_tab ){
                return explorer.query_tabs[i];
            }
        }
        return {};

    },
    constraint_image: function( constraint ){
        var images = new Array();
        if( /Maybe/.test( constraint ) ){ images.push('maybe'); }else{ images.push('empty'); }
        if( /Str/.test( constraint ) ){ images.push('string'); }
        if( /DateTime/.test( constraint ) ){ images.push('date'); }
        if( /(Num|Int)/.test( constraint ) ){ images.push('number'); }
        if( /MongoDB::OID/.test( constraint ) ){ images.push('key'); }
        if( /Mongoose::Join::Relational/.test( constraint ) ){ images.push('join'); }
        if( /::/.test( constraint ) && images.length == 1 ){ images.push('object'); }
        return images;
    },
    constraint_link: function( constraint ){
        if( ! /(Str|DateTime|Num|Int|OID)/.test( constraint ) ){
            if( /Join/.test(constraint) ){
                var class_name = constraint.match(/Mongoose::Join::Relational\[(.*?)\]/);
                return 'Mongoose::Join::Relational[<a href="javascript:explorer.pages.explore_class(\'' + class_name[1] + '\')">' + class_name[1] + '</a>]';
            }else{
                return '<a href="javascript:explorer.pages.explore_class(\'' + constraint + '\')">' + constraint + '</a>';
            }
        }
        return constraint;
    },
    list_collections: function( target ){
            explorer.ajax_wait("ul.subnav");
            $.ajax({ url: '/eval/', dataType: 'json', data: { code: '{ classes => $db->{collection_to_class} }' }, success: function(data){
                var b = [];
                for (k in data.classes) b.push(k);
                b.sort();
                data.sorted = b;
                $("ul.subnav").empty();
                data.target = target;
                $('#list_collection_tpl').tmpl(data).appendTo("ul.subnav");
            } });
    },
    refresh_query_tabs: function(){
        $('#subnav').empty();
        $('#query_tabs_tpl').tmpl({tabs: explorer.query_tabs, current: explorer.current_query_tab}).appendTo("#subnav");
        if( explorer.query_tabs.length > 0 ){
            $('#subnav').show('slow');
        }else{
            $('#subnav').hide('slow');
        }
    },
    ajax_wait: function( selector ){
        $(selector).empty();
        $('#ajax_wait_tpl').tmpl({}).appendTo(selector);
    }
};

//home
$(document).ready(function() {
    explorer.pages.header();
    explorer.pages.query();
});


