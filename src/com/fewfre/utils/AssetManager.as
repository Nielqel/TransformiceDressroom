package com.fewfre.utils
{
	import com.fewfre.events.FewfEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.ErrorEvent;
	import flash.events.EventDispatcher;
	import flash.net.*;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Bitmap;
	import flash.display.LoaderInfo;
	import flash.display.BitmapData;
	import flash.utils.Dictionary;
	import flash.utils.setTimeout;
	import flash.external.ExternalInterface;
	
	public class AssetManager extends EventDispatcher
	{
		// Constants
		public static const LOADING_FINISHED:String = "asset_loading_finished";
		public static const PACK_LOADED:String = "asset_pack_loaded";
		
		// Storage
		internal var _cacheBreaker:String;
		
		internal var _urlsToLoad:Array;
		internal var _loadedStuffCallbacks:Array; // Store all loaded stuff in here to allow async loading, but still force loading in specified order.
		internal var _itemsLeftToLoad:Number;
		
		internal var _applicationDomains:Array;
		internal var _loadedData:Dictionary;
		
		// Properties
		public function get itemsLeftToLoad():int { return _itemsLeftToLoad; }//_urlsToLoad.length; }
		
		public function AssetManager() {
			super();
			_applicationDomains = [];
			_loadedData = new Dictionary();
			_cacheBreaker = null;
		}
		
		/****************************
		* Loading
		*****************************/
			// options ?= { cacheBreaker?:Boolean }
			public function loadWithCallback(pURLs:Array, pCallback:Function, options:Object=null) : void {
				options = options || {};
				load(pURLs, options.cacheBreaker);
				addEventListener(AssetManager.LOADING_FINISHED, function fDone(event:Event){
					removeEventListener(AssetManager.LOADING_FINISHED, fDone);
					pCallback(null);
				});
				addEventListener(ErrorEvent.ERROR, function fDone(event:ErrorEvent){
					removeEventListener(AssetManager.LOADING_FINISHED, fDone);
					pCallback("error");
				});
			}
			
			public function load(pURLs:Array, pCacheBreaker:String=null) : void {
				_urlsToLoad = pURLs;
				_itemsLeftToLoad = _urlsToLoad.length;
				_loadedStuffCallbacks = [];
				_cacheBreaker = pCacheBreaker;
				var i = -1;
				while(_urlsToLoad.length > 0) { i++;
					_loadedStuffCallbacks.push(null);
					_loadNextItem(i);
				}
			}
			
			private function _loadNextItem(i:int) : void {
				var tItem:* = _urlsToLoad.shift();
				if(!(tItem is Array)) {
					_newLoader( i, tItem );
				} else {
					_newLoader( i, tItem[0], tItem[1] );
				}
			}
			
			private function _newLoader(pIndex:int, pUrl:String, pOptions:Object=null) : void {
				var tUrlParts:Array = pUrl.split("/").pop().split("."), tName:String = tUrlParts[0], tType:String = tUrlParts[1];
				if(_cacheBreaker && (Fewf.isExternallyLoaded ? true : ExternalInterface.available ? ExternalInterface.call("eval", "window.location.href") : false)) {
					pUrl += "?cb="+_cacheBreaker;
				}
				pOptions = pOptions || {};
				if(pOptions.type) { tType = pOptions.type; }
				if(pOptions.name) { tName = pOptions.name; }
				switch(tType) {
					case "swf":
					case "swc":
						var tLoader = new AssetManagerBinaryLoader();
						tLoader.load(pUrl, pOptions.useCurrentDomain);
						tLoader.addEventListener(Event.COMPLETE, function(e:Event):void{ _onAssetsLoaded(pIndex, tLoader, arguments.callee); });
						tLoader.addEventListener(IOErrorEvent.IO_ERROR, _onLoadError);
						tLoader.addEventListener(ProgressEvent.PROGRESS, _onProgress);
						break;
					case "txt":
					case "json":
						var tUrlLoader:URLLoader = new URLLoader();
						tUrlLoader.addEventListener(Event.COMPLETE, function(e:Event):void{ _onTextLoaded(pIndex, e, tName, tType, arguments.callee); });
						tUrlLoader.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event):void{ _onURLLoadError(e as IOErrorEvent, pUrl, arguments.callee); });
						tUrlLoader.addEventListener(ProgressEvent.PROGRESS, _onProgress);
						var tRequest2:URLRequest = new URLRequest(pUrl);
						tRequest2.requestHeaders.push(new URLRequestHeader("pragma", "no-cache"));
						tUrlLoader.load(tRequest2);
						break;
					default:
						trace("[AssetManager](_newLoader) Unknown file type: "+tType);
						break;
				}
			}
			
			private function _destroyAssetLoader(pLoader:Loader, pOnComplete) : void {
				pLoader.contentLoaderInfo.removeEventListener(Event.COMPLETE, pOnComplete);//_onAssetsLoaded);
				pLoader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, _onLoadError);
				pLoader.contentLoaderInfo.removeEventListener(ProgressEvent.PROGRESS, _onProgress);
			}
			
			private function _destroyURLLoader(pLoader:URLLoader, pOnComplete) : void {
				pLoader.removeEventListener(Event.COMPLETE, pOnComplete);
				pLoader.removeEventListener(IOErrorEvent.IO_ERROR, _onURLLoadError);
				pLoader.removeEventListener(ProgressEvent.PROGRESS, _onProgress);
			}
			
			private function _onAssetsLoaded(pIndex:int, l:AssetManagerBinaryLoader, pOnComplete) : void {
				_loadedStuffCallbacks[pIndex] = function():void{
					_applicationDomains.push( l.applicationDomain );
					l.destroy();
				};
				_checkIfLoadingDone();
			}
			
			private function _onTextLoaded(pIndex:int, e:Event, pKey:String, pType:String, pOnComplete) : void {
				_loadedStuffCallbacks[pIndex] = function():void{
					_loadedData[pKey] = pType === "json" ? JSON.parse(e.target.data) : e.target.data;
					_destroyURLLoader(e.target as URLLoader, pOnComplete);
				};
				_checkIfLoadingDone();
			}
			
			private function _onLoadError(e:ErrorEvent) : void {
				try {
					trace("[AssetManager](_onLoadError) ERROR("+e.errorID+"): Was not able to load url: "+e.target.url);
					Fewf.dispatcher.dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "["+e.type+":"+e.errorID+"] "+e.text));
				} catch(err:Error) {}
				// _destroyAssetLoader(e.target.loader, pOnComplete);
				_checkIfLoadingDone();
			}
			
			private function _onURLLoadError(e:IOErrorEvent, pUrl:String, pOnComplete) : void {
				try {
					trace("[AssetManager](_onLoadError) ERROR("+e.errorID+"): Was not able to load url: "+pUrl);
					_destroyURLLoader(e.target as URLLoader, pOnComplete);
				} catch(err:Error) {}
				_checkIfLoadingDone();
			}
			
			private function _onProgress(e:ProgressEvent) : void {
				dispatchEvent(e);
				//trace("Loading: "+String(Math.floor(e.bytesLoaded/1024))+" KB of "+String(Math.floor(e.bytesTotal/1024))+" KB.");
			}
			
			private function _checkIfLoadingDone() : void {
				_itemsLeftToLoad--;
				dispatchEvent(new FewfEvent(PACK_LOADED, { itemsLeftToLoad:itemsLeftToLoad }));
				if(itemsLeftToLoad > 0) {
					// _loadNextItem();
				} else {
					trace("[AssetManager](_checkIfLoadingDone) All resources loaded.");
					for each(var pCallback:Function in _loadedStuffCallbacks) {
						if(pCallback != null) { pCallback(); }
					}
					_loadedStuffCallbacks = null;
					trace("[AssetManager](_checkIfLoadingDone) All resources stored.");
					setTimeout(function():void{ dispatchEvent(new Event(AssetManager.LOADING_FINISHED)); }, 0);
				}
			}
		
		/****************************
		* Access Assets
		*****************************/
		public function getData(pKey:String) : * {
			return _loadedData[pKey];
		}
		
		public function getLoadedClass(pName:String, pTrace:Boolean=false) : Class {
			for(var i:int = 0; i < _applicationDomains.length; i++) {
				if(_applicationDomains[i].hasDefinition(pName)) {
					return _applicationDomains[i].getDefinition( pName ) as Class;
				}
			}
			if(pTrace) { trace("[AssetManager](getLoadedClass) ERROR: No Linkage by name: "+pName); }
			return null;
		}
		public function getLoadedMovieClip(pName:String, pDontReturnNull:Boolean=false, pTrace:Boolean=false) : MovieClip {
			var tClass:Class = getLoadedClass(pName, pTrace);
			return tClass ? new tClass() : (pDontReturnNull ? new MovieClip() : null);
		}
		
		/****************************
		* Bitmap Loader
		*****************************/
		public static const _DICT_getLoadedBitmapFromUrl:Dictionary = new Dictionary();
		public static const _DICT_bitmapsNeedingToBeDrawnAfterImageLoaded:Dictionary = new Dictionary();
		
		public function lazyLoadImageUrlAsBitmap(pFilePath:String) : Bitmap {
			var url:String = pFilePath.indexOf("http") == 0 ? pFilePath : ((Fewf.swfUrlBase || "https://projects.fewfre.com/a801/transformice/dressroom/")+"resources/" + pFilePath);
			var tBitmap:Bitmap = new Bitmap();
			if(_DICT_getLoadedBitmapFromUrl[url]) {
				tBitmap.bitmapData = _DICT_getLoadedBitmapFromUrl[url];
			} else {
				if(_DICT_bitmapsNeedingToBeDrawnAfterImageLoaded[url]) {
					_DICT_bitmapsNeedingToBeDrawnAfterImageLoaded[url].push(tBitmap);
				} else {
					_DICT_bitmapsNeedingToBeDrawnAfterImageLoaded[url] = new Array(tBitmap);
					_createBitmapLoader(url);
				}
			}
			return tBitmap;
		}
		
		private function _createBitmapLoader(pUrl:String) : void {
			try {
				var tLoader:Loader = new Loader();
				tLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, _onBitmapLazyLoaded);
				// tLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, _onError_bitmapLazyLoader);
				tLoader.load(new URLRequest(pUrl));
			} catch(err:Error) {}
		}
		
		private function _onBitmapLazyLoaded(e:Event) : void {
			try {
				var tLoader:Loader = null;
				tLoader = (e.currentTarget as LoaderInfo).loader;
				var tBitmapData:BitmapData = Bitmap(tLoader.content).bitmapData;
				var tUrl:String = (e.currentTarget as LoaderInfo).url; // NOTE: future me, remember that this only works if not using cache breaker
				_DICT_getLoadedBitmapFromUrl[tUrl] = tBitmapData;
				
				var tBitmapsNeedingDrawing:Array = _DICT_bitmapsNeedingToBeDrawnAfterImageLoaded[tUrl];
				if(tBitmapsNeedingDrawing) {
					delete _DICT_bitmapsNeedingToBeDrawnAfterImageLoaded[tUrl];
					for(var i:int = 0; i < tBitmapsNeedingDrawing.length; i++) {
						(tBitmapsNeedingDrawing[i] as Bitmap).bitmapData = tBitmapData;
						(tBitmapsNeedingDrawing[i] as Bitmap).dispatchEvent(new Event(Event.COMPLETE));
					}
				}
			} catch(err:Error) {}
		}
	}
}