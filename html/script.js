// Enhanced Vehicle Loader UI Script

class VehicleLoaderUI {
  constructor() {
    // State management
    this.currentTrailer = null;
    this.currentLocale = {};
    this.vehicleClasses = {};
    this.isLoading = false;
    this.lastUpdate = null;
    this.autoRefreshInterval = null;
    this.connectionStatus = "connected";
    this.filteredVehicles = [];
    this.selectedVehicle = null;

    // UI Elements
    this.initializeElements();

    // Event bindings
    this.setupEventListeners();
    this.setupKeyBindings();

    // Auto-refresh setup
    this.startAutoRefresh();

    // Debug mode check
    this.debugMode = window.location.search.includes("debug=true");
    if (this.debugMode) {
      this.setupDebugMode();
    }
  }

  initializeElements() {
    // Main app elements
    this.app = document.getElementById("app");
    this.loadingOverlay = document.getElementById("loading-overlay");
    this.loadingText = document.getElementById("loading-text");
    this.loadingProgressBar = document.getElementById("loading-progress-bar");
    this.loadingStep = document.getElementById("loading-step");
    this.notificationContainer = document.getElementById(
      "notification-container"
    );

    // Menu elements
    this.menuTitle = document.getElementById("menu-title");
    this.closeBtn = document.getElementById("close-btn");
    this.trailerModel = document.getElementById("trailer-model");
    this.trailerCapacity = document.getElementById("trailer-capacity");
    this.trailerLoaded = document.getElementById("trailer-loaded");

    // Vehicle list elements
    this.loadedVehiclesList = document.getElementById("loaded-vehicles-list");
    this.availableVehiclesList = document.getElementById(
      "available-vehicles-list"
    );
    this.vehicleSearch = document.getElementById("vehicle-search");
    this.classFilter = document.getElementById("class-filter");
    this.refreshBtn = document.getElementById("refresh-btn");
    this.vehicleCount = document.getElementById("vehicle-count");
    this.distanceRange = document.getElementById("distance-range");
    this.distanceValue = document.getElementById("distance-value");

    // Status elements
    this.connectionStatus = document.getElementById("connection-status");
    this.lastUpdateElement = document.getElementById("last-update");

    // Dialog elements
    this.confirmationDialog = document.getElementById("confirmation-dialog");
    this.dialogTitle = document.getElementById("dialog-title");
    this.dialogMessage = document.getElementById("dialog-message");
    this.dialogConfirm = document.getElementById("dialog-confirm");
    this.dialogCancel = document.getElementById("dialog-cancel");

    // Context menu elements
    this.contextMenu = document.getElementById("context-menu");

    // Modal elements
    this.vehicleInfoModal = document.getElementById("vehicle-info-modal");
    this.modalClose = document.getElementById("modal-close");
    this.vehicleInfoContent = document.getElementById("vehicle-info-content");
  }

  setupEventListeners() {
    // Basic controls
    this.closeBtn.addEventListener("click", () => this.closeMenu());
    this.vehicleSearch.addEventListener("input", () => this.filterVehicles());
    this.classFilter.addEventListener("change", () => this.filterVehicles());
    this.refreshBtn.addEventListener("click", () => this.requestMenuUpdate());

    // Distance filter
    this.distanceRange.addEventListener("input", (e) => {
      this.distanceValue.textContent = e.target.value + "m";
      this.filterVehicles();
    });

    // Dialog controls
    this.dialogCancel.addEventListener("click", () =>
      this.hideConfirmationDialog()
    );
    this.modalClose.addEventListener("click", () =>
      this.hideVehicleInfoModal()
    );

    // Click outside to close
    this.confirmationDialog.addEventListener("click", (e) => {
      if (e.target === this.confirmationDialog) {
        this.hideConfirmationDialog();
      }
    });

    this.vehicleInfoModal.addEventListener("click", (e) => {
      if (e.target === this.vehicleInfoModal) {
        this.hideVehicleInfoModal();
      }
    });

    // Context menu
    document.addEventListener("click", () => this.hideContextMenu());
    this.contextMenu.addEventListener("click", (e) => {
      e.stopPropagation();
      this.handleContextMenuAction(e.target.closest(".context-menu-item"));
    });

    // Prevent right-click context menu on vehicle items
    document.addEventListener("contextmenu", (e) => {
      const vehicleItem = e.target.closest(".vehicle-item");
      if (vehicleItem) {
        e.preventDefault();
        this.showContextMenu(e, vehicleItem);
      }
    });

    // Auto-refresh controls
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        this.stopAutoRefresh();
      } else {
        this.startAutoRefresh();
      }
    });
  }

  setupKeyBindings() {
    document.addEventListener("keydown", (e) => {
      switch (e.key) {
        case "Escape":
          if (
            this.vehicleInfoModal &&
            !this.vehicleInfoModal.classList.contains("hidden")
          ) {
            this.hideVehicleInfoModal();
          } else if (
            this.confirmationDialog &&
            !this.confirmationDialog.classList.contains("hidden")
          ) {
            this.hideConfirmationDialog();
          } else {
            this.closeMenu();
          }
          break;
        case "F5":
          e.preventDefault();
          this.requestMenuUpdate();
          break;
        case "Enter":
          if (
            this.vehicleSearch === document.activeElement &&
            this.filteredVehicles.length > 0
          ) {
            this.loadVehicle(this.filteredVehicles[0].entity);
          }
          break;
      }
    });
  }

  // NUI Message Handler
  handleNUIMessage(event) {
    const data = event.data;

    try {
      switch (data.type) {
        case "openMenu":
          this.openMenu(data);
          break;
        case "updateTrailer":
          this.updateTrailerInfo(data.trailer);
          this.updateVehicleLists(data.trailer);
          break;
        case "showNotification":
          this.showNotification(
            data.message,
            data.notificationType || "info",
            data.duration
          );
          break;
        case "showLoading":
          this.showLoading(data.message);
          break;
        case "hideLoading":
          this.hideLoading();
          break;
        case "updateLoadingProgress":
          this.updateLoadingProgress(data.progress);
          break;
        case "updateConnectionStatus":
          this.updateConnectionStatus(data.status);
          break;
      }
    } catch (error) {
      console.error("[VehicleLoader] Error handling NUI message:", error);
      this.showNotification("UI Error: " + error.message, "error");
    }
  }

  openMenu(data) {
    this.currentTrailer = data.trailer;
    this.currentLocale = data.locale;
    this.vehicleClasses = data.vehicleClasses;
    this.lastUpdate = new Date();

    this.updateLocalization();
    this.updateTrailerInfo(data.trailer);
    this.updateVehicleLists(data.trailer);
    this.populateClassFilter();
    this.updateLastUpdateTime();

    this.app.classList.remove("hidden");
    this.playSound("menu_open");
  }

  closeMenu() {
    this.app.classList.add("hidden");
    this.currentTrailer = null;
    this.stopAutoRefresh();
    this.hideContextMenu();
    this.hideConfirmationDialog();
    this.hideVehicleInfoModal();

    this.playSound("menu_close");

    // Send close event to client
    this.sendNUICallback("closeMenu", {});
  }

  updateLocalization() {
    const elements = {
      "menu-title": "menu_title",
      "trailer-info-title": "trailer_info",
      "loaded-vehicles-title": "loaded_vehicles",
      "available-vehicles-title": "available_vehicles",
      "model-label": "model",
      "capacity-label": "capacity",
      "loaded-label": "loaded",
      "no-vehicles-loaded": "no_vehicles_loaded",
      "no-vehicles-available": "no_vehicles_available",
    };

    Object.entries(elements).forEach(([id, key]) => {
      const element = document.getElementById(id);
      if (element && this.currentLocale[key]) {
        element.textContent = this.currentLocale[key];
      }
    });

    // Update placeholders
    if (this.vehicleSearch && this.currentLocale.search_placeholder) {
      this.vehicleSearch.placeholder = this.currentLocale.search_placeholder;
    }
  }

  updateTrailerInfo(trailer) {
    if (!trailer) return;

    this.trailerModel.textContent = (
      trailer.config.displayName || trailer.model
    ).toUpperCase();
    this.trailerCapacity.textContent = `${trailer.loadedVehicles.length}/${trailer.config.maxVehicles}`;
    this.trailerLoaded.textContent = `${trailer.loadedVehicles.length} ${
      this.currentLocale.vehicles || "vehicles"
    }`;
  }

  updateVehicleLists(trailer) {
    this.updateLoadedVehicles(trailer.loadedVehicles);
    this.updateAvailableVehicles(trailer.nearbyVehicles);
    this.updateLastUpdateTime();
  }

  updateLoadedVehicles(loadedVehicles) {
    this.loadedVehiclesList.innerHTML = "";

    if (!loadedVehicles || loadedVehicles.length === 0) {
      this.loadedVehiclesList.innerHTML = `
              <div class="empty-state">
                  <p>${
                    this.currentLocale.no_vehicles_loaded ||
                    "No vehicles loaded"
                  }</p>
              </div>
          `;
      return;
    }

    loadedVehicles.forEach((vehicle) => {
      const vehicleElement = this.createLoadedVehicleElement(vehicle);
      this.loadedVehiclesList.appendChild(vehicleElement);
    });
  }

  createLoadedVehicleElement(vehicle) {
    const div = document.createElement("div");
    div.className = "vehicle-item loaded";
    div.dataset.vehicleId = vehicle.entity;
    div.dataset.slot = vehicle.slot;

    div.innerHTML = `
          <div class="vehicle-info">
              <div class="vehicle-name">${vehicle.displayName}</div>
              <div class="vehicle-details">
                  <span class="vehicle-class">${vehicle.className}</span>
                  <span class="vehicle-slot">${
                    this.currentLocale.slot || "Slot"
                  } ${vehicle.slot}</span>
              </div>
          </div>
          <div class="vehicle-actions">
              <button class="btn btn-unload" onclick="vehicleLoader.unloadVehicle(${
                vehicle.slot
              })" 
                      title="${this.currentLocale.unload_vehicle || "Unload"}">
                  ${this.currentLocale.unload_vehicle || "Unload"}
              </button>
          </div>
      `;

    return div;
  }

  updateAvailableVehicles(availableVehicles) {
    this.availableVehiclesList.innerHTML = "";

    if (!availableVehicles || availableVehicles.length === 0) {
      this.availableVehiclesList.innerHTML = `
              <div class="empty-state">
                  <p>${
                    this.currentLocale.no_vehicles_available ||
                    "No vehicles available"
                  }</p>
              </div>
          `;
      this.updateVehicleCount(0);
      return;
    }

    // Store for filtering
    this.allVehicles = availableVehicles;
    this.filterVehicles();
  }

  createAvailableVehicleElement(vehicle) {
    const div = document.createElement("div");
    div.className = "vehicle-item";
    div.dataset.vehicleId = vehicle.entity;
    div.dataset.vehicleName = vehicle.displayName.toLowerCase();
    div.dataset.vehicleClass = vehicle.class;
    div.dataset.vehicleDistance = vehicle.distance;

    const distanceColor = this.getDistanceColor(vehicle.distance);

    div.innerHTML = `
          <div class="vehicle-info">
              <div class="vehicle-name">${vehicle.displayName}</div>
              <div class="vehicle-details">
                  <span class="vehicle-class">${vehicle.className}</span>
                  <span class="vehicle-distance" style="color: ${distanceColor}">
                      ${Math.round(vehicle.distance)}m
                  </span>
              </div>
          </div>
          <div class="vehicle-actions">
              <button class="btn btn-load" onclick="vehicleLoader.loadVehicle(${
                vehicle.entity
              })"
                      title="${this.currentLocale.load_vehicle || "Load"}">
                  ${this.currentLocale.load_vehicle || "Load"}
              </button>
          </div>
      `;

    return div;
  }

  populateClassFilter() {
    this.classFilter.innerHTML = `<option value="">${
      this.currentLocale.all_classes || "All Classes"
    }</option>`;

    if (!this.currentTrailer || !this.currentTrailer.config.allowedClasses)
      return;

    this.currentTrailer.config.allowedClasses.forEach((classId) => {
      const className = this.vehicleClasses[classId];
      if (className) {
        const option = document.createElement("option");
        option.value = classId;
        option.textContent = className;
        this.classFilter.appendChild(option);
      }
    });
  }

  filterVehicles() {
    if (!this.allVehicles) return;

    const searchTerm = this.vehicleSearch.value.toLowerCase();
    const selectedClass = this.classFilter.value;
    const maxDistance = parseInt(this.distanceRange.value);

    this.filteredVehicles = this.allVehicles.filter((vehicle) => {
      const matchesSearch =
        !searchTerm || vehicle.displayName.toLowerCase().includes(searchTerm);
      const matchesClass =
        !selectedClass || vehicle.class.toString() === selectedClass;
      const matchesDistance = vehicle.distance <= maxDistance;

      return matchesSearch && matchesClass && matchesDistance;
    });

    this.renderFilteredVehicles();
    this.updateVehicleCount(this.filteredVehicles.length);
  }

  renderFilteredVehicles() {
    this.availableVehiclesList.innerHTML = "";

    if (this.filteredVehicles.length === 0) {
      this.availableVehiclesList.innerHTML = `
              <div class="empty-state no-results">
                  <p>No vehicles match your search criteria</p>
              </div>
          `;
      return;
    }

    this.filteredVehicles.forEach((vehicle) => {
      const vehicleElement = this.createAvailableVehicleElement(vehicle);
      this.availableVehiclesList.appendChild(vehicleElement);
    });
  }

  updateVehicleCount(count) {
    this.vehicleCount.textContent = `${count} ${
      count === 1 ? "vehicle" : "vehicles"
    } found`;
  }

  getDistanceColor(distance) {
    if (distance <= 10) return "#4CAF50"; // Green
    if (distance <= 20) return "#FFC107"; // Orange
    if (distance <= 35) return "#FF9800"; // Dark Orange
    return "#F44336"; // Red
  }

  // Vehicle operations
  loadVehicle(vehicleId) {
    if (this.isLoading) {
      this.showNotification(
        this.currentLocale.operation_in_progress || "Operation in progress",
        "warning"
      );
      return;
    }

    this.showConfirmationDialog(
      "Load Vehicle",
      "Are you sure you want to load this vehicle?",
      () => {
        this.isLoading = true;
        this.sendNUICallback("loadVehicle", { vehicleId }, (result) => {
          this.isLoading = false;
          this.handleOperationResult(result);
        });
      }
    );
  }

  unloadVehicle(slotIndex) {
    if (this.isLoading) {
      this.showNotification(
        this.currentLocale.operation_in_progress || "Operation in progress",
        "warning"
      );
      return;
    }

    this.showConfirmationDialog(
      "Unload Vehicle",
      "Are you sure you want to unload this vehicle?",
      () => {
        this.isLoading = true;
        this.sendNUICallback("unloadVehicle", { slotIndex }, (result) => {
          this.isLoading = false;
          this.handleOperationResult(result);
        });
      }
    );
  }

  handleOperationResult(result) {
    if (result.success) {
      this.showNotification(result.message, "success");
      this.playSound("success");
      setTimeout(() => this.requestMenuUpdate(), 1000);
    } else {
      this.showNotification(result.message, "error");
      this.playSound("error");
    }
  }

  requestMenuUpdate() {
    this.sendNUICallback("requestUpdate", {});
    this.showNotification("Refreshing...", "info", 1000);
  }

  // UI Components
  showLoading(message = "Loading...") {
    this.loadingText.textContent = message;
    this.loadingStep.textContent = "Initializing...";
    this.loadingProgressBar.style.width = "0%";
    this.loadingOverlay.classList.remove("hidden");
  }

  hideLoading() {
    this.loadingOverlay.classList.add("hidden");
  }

  updateLoadingProgress(progress) {
    this.loadingProgressBar.style.width = `${progress}%`;

    if (progress < 25) {
      this.loadingStep.textContent = "Preparing...";
    } else if (progress < 50) {
      this.loadingStep.textContent = "Processing...";
    } else if (progress < 75) {
      this.loadingStep.textContent = "Finalizing...";
    } else {
      this.loadingStep.textContent = "Almost done...";
    }
  }

  showNotification(message, type = "info", duration = 4000) {
    const notification = document.createElement("div");
    notification.className = `notification ${type}`;
    notification.innerHTML = `
          <div class="notification-content">
              <span class="notification-icon">${this.getNotificationIcon(
                type
              )}</span>
              <span class="notification-message">${message}</span>
              <button class="notification-close" onclick="this.parentNode.parentNode.remove()">&times;</button>
          </div>
      `;

    this.notificationContainer.appendChild(notification);

    // Auto remove
    setTimeout(() => {
      if (notification.parentNode) {
        notification.style.animation =
          "slideOutNotification 0.3s ease-in forwards";
        setTimeout(() => {
          if (notification.parentNode) {
            notification.remove();
          }
        }, 300);
      }
    }, duration);

    // Click to dismiss
    notification.addEventListener("click", () => {
      if (notification.parentNode) {
        notification.remove();
      }
    });
  }

  getNotificationIcon(type) {
    const icons = {
      success: "✅",
      error: "❌",
      warning: "⚠️",
      info: "ℹ️",
    };
    return icons[type] || icons.info;
  }

  showConfirmationDialog(title, message, onConfirm) {
    this.dialogTitle.textContent = title;
    this.dialogMessage.textContent = message;

    this.dialogConfirm.onclick = () => {
      this.hideConfirmationDialog();
      onConfirm();
    };

    this.confirmationDialog.classList.remove("hidden");
  }

  hideConfirmationDialog() {
    this.confirmationDialog.classList.add("hidden");
    this.dialogConfirm.onclick = null;
  }

  showContextMenu(event, vehicleItem) {
    const vehicleId = vehicleItem.dataset.vehicleId;
    const isLoaded = vehicleItem.classList.contains("loaded");

    this.selectedVehicle = {
      id: vehicleId,
      element: vehicleItem,
      loaded: isLoaded,
    };

    // Show/hide menu items based on context
    const loadItem = this.contextMenu.querySelector('[data-action="load"]');
    const unloadItem = this.contextMenu.querySelector('[data-action="unload"]');

    loadItem.style.display = isLoaded ? "none" : "block";
    unloadItem.style.display = isLoaded ? "block" : "none";

    // Position menu
    this.contextMenu.style.left = `${event.clientX}px`;
    this.contextMenu.style.top = `${event.clientY}px`;
    this.contextMenu.classList.remove("hidden");
  }

  hideContextMenu() {
    this.contextMenu.classList.add("hidden");
    this.selectedVehicle = null;
  }

  handleContextMenuAction(item) {
    if (!item || !this.selectedVehicle) return;

    const action = item.dataset.action;
    this.hideContextMenu();

    switch (action) {
      case "load":
        this.loadVehicle(this.selectedVehicle.id);
        break;
      case "unload":
        const slot = this.selectedVehicle.element.dataset.slot;
        this.unloadVehicle(parseInt(slot));
        break;
      case "info":
        this.showVehicleInfo(this.selectedVehicle.id);
        break;
    }
  }

  showVehicleInfo(vehicleId) {
    // Find vehicle data
    const vehicle =
      this.allVehicles?.find((v) => v.entity == vehicleId) ||
      this.currentTrailer?.loadedVehicles?.find((v) => v.entity == vehicleId);

    if (!vehicle) return;

    this.vehicleInfoContent.innerHTML = `
          <div class="info-row">
              <span class="info-label">Name:</span>
              <span class="info-value">${vehicle.displayName}</span>
          </div>
          <div class="info-row">
              <span class="info-label">Class:</span>
              <span class="info-value">${vehicle.className}</span>
          </div>
          <div class="info-row">
              <span class="info-label">Model:</span>
              <span class="info-value">${vehicle.model}</span>
          </div>
          ${
            vehicle.distance
              ? `
              <div class="info-row">
                  <span class="info-label">Distance:</span>
                  <span class="info-value">${Math.round(
                    vehicle.distance
                  )}m</span>
              </div>
          `
              : ""
          }
          ${
            vehicle.slot
              ? `
              <div class="info-row">
                  <span class="info-label">Slot:</span>
                  <span class="info-value">${vehicle.slot}</span>
              </div>
          `
              : ""
          }
      `;

    this.vehicleInfoModal.classList.remove("hidden");
  }

  hideVehicleInfoModal() {
    this.vehicleInfoModal.classList.add("hidden");
  }

  // Auto-refresh functionality
  startAutoRefresh() {
    if (this.autoRefreshInterval) return;

    this.autoRefreshInterval = setInterval(() => {
      if (!this.app.classList.contains("hidden") && !this.isLoading) {
        this.requestMenuUpdate();
      }
    }, 10000); // Refresh every 10 seconds
  }

  stopAutoRefresh() {
    if (this.autoRefreshInterval) {
      clearInterval(this.autoRefreshInterval);
      this.autoRefreshInterval = null;
    }
  }

  updateConnectionStatus(status) {
    this.connectionStatus.className = `status-indicator ${status}`;
    this.connectionStatus.textContent =
      status.charAt(0).toUpperCase() + status.slice(1);
  }

  updateLastUpdateTime() {
    this.lastUpdate = new Date();
    this.lastUpdateElement.textContent = `Last updated: ${this.lastUpdate.toLocaleTimeString()}`;
  }

  // Utility functions
  sendNUICallback(endpoint, data = {}, callback = null) {
    // In development/testing mode, simulate responses
    if (this.debugMode || window.location.protocol === "file:") {
      console.log(
        `[VehicleLoader] Debug: Simulating callback for ${endpoint}`,
        data
      );

      if (callback) {
        setTimeout(() => {
          const mockResponse = this.getMockResponse(endpoint, data);
          callback(mockResponse);
        }, 100);
      }
      return;
    }

    fetch(`https://${this.getParentResourceName()}/${endpoint}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    })
      .then((response) => {
        // Check if response is ok and has content
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }

        // Check if response has content
        const contentType = response.headers.get("content-type");
        if (contentType && contentType.indexOf("application/json") !== -1) {
          return response.json();
        } else {
          // If no JSON content, return empty object
          return {};
        }
      })
      .then((result) => {
        if (callback) callback(result);
      })
      .catch((error) => {
        console.error(
          `[VehicleLoader] NUI Callback Error (${endpoint}):`,
          error
        );

        // For certain endpoints, don't show error notifications
        if (endpoint !== "closeMenu" && endpoint !== "requestUpdate") {
          this.showNotification(
            "Connection error - Check if resource is running",
            "error"
          );
          this.updateConnectionStatus("disconnected");
        }

        // Call callback with default result if provided
        if (callback) {
          callback({ success: false, message: "Connection error" });
        }
      });
  }

  getMockResponse(endpoint, data) {
    switch (endpoint) {
      case "closeMenu":
        return { status: "ok" };
      case "loadVehicle":
        return {
          success: true,
          message: "Vehicle loaded successfully (Debug Mode)",
        };
      case "unloadVehicle":
        return {
          success: true,
          message: "Vehicle unloaded successfully (Debug Mode)",
        };
      case "requestUpdate":
        return { status: "ok" };
      default:
        return { success: false, message: "Unknown endpoint" };
    }
  }

  getParentResourceName() {
    return window.location.hostname;
  }

  playSound(soundType) {
    // Could implement HTML5 audio or send to client
    console.log(`[VehicleLoader] Playing sound: ${soundType}`);
  }

  setupDebugMode() {
    console.log("[VehicleLoader] Debug mode enabled");

    // Add debug panel
    const debugPanel = document.createElement("div");
    debugPanel.style.cssText = `
          position: fixed; top: 10px; left: 10px; background: rgba(0,0,0,0.8);
          color: white; padding: 10px; border-radius: 5px; font-family: monospace;
          z-index: 10000; font-size: 12px;
      `;
    debugPanel.innerHTML = `
          <div>Vehicle Loader Debug</div>
          <button onclick="vehicleLoader.testLoadMockData()">Load Mock Data</button>
      `;
    document.body.appendChild(debugPanel);

    // Mock data for testing
    setTimeout(() => {
      this.testLoadMockData();
    }, 1000);
  }

  testLoadMockData() {
    const mockData = {
      type: "openMenu",
      trailer: {
        model: "tr2",
        config: {
          maxVehicles: 2,
          allowedClasses: [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12],
          displayName: "Car Trailer",
        },
        loadedVehicles: [
          {
            slot: 1,
            entity: 123,
            displayName: "Adder",
            class: 7,
            className: "Super",
            model: "adder",
          },
        ],
        nearbyVehicles: [
          {
            entity: 456,
            displayName: "Zentorno",
            class: 7,
            className: "Super",
            distance: 5.2,
            model: "zentorno",
          },
          {
            entity: 789,
            displayName: "Infernus",
            class: 7,
            className: "Super",
            distance: 8.7,
            model: "infernus",
          },
          {
            entity: 101,
            displayName: "Sultan",
            class: 1,
            className: "Sedans",
            distance: 12.3,
            model: "sultan",
          },
        ],
      },
      locale: {
        menu_title: "Vehicle Loader",
        load_vehicle: "Load",
        unload_vehicle: "Unload",
        vehicle_loaded: "Vehicle loaded successfully",
        vehicle_unloaded: "Vehicle unloaded successfully",
        loading_failed: "Failed to load vehicle",
        unloading_failed: "Failed to unload vehicle",
        trailer_info: "Trailer Information",
        loaded_vehicles: "Loaded Vehicles",
        available_vehicles: "Available Vehicles",
        no_vehicles_loaded: "No vehicles loaded",
        no_vehicles_available: "No vehicles available",
        search_placeholder: "Search vehicles...",
        all_classes: "All Classes",
        model: "Model",
        capacity: "Capacity",
        loaded: "Loaded",
        vehicles: "vehicles",
        slot: "Slot",
      },
      vehicleClasses: {
        0: "Compacts",
        1: "Sedans",
        2: "SUVs",
        3: "Coupes",
        4: "Muscle",
        5: "Sports Classics",
        6: "Sports",
        7: "Super",
        8: "Motorcycles",
        9: "Off-road",
        10: "Industrial",
        11: "Utility",
        12: "Vans",
      },
    };

    this.handleNUIMessage({ data: mockData });
  }
}

// Global instance
const vehicleLoader = new VehicleLoaderUI();

// Event listeners
window.addEventListener("message", (event) => {
  vehicleLoader.handleNUIMessage(event);
});

// CSS animations
const styleSheet = document.createElement("style");
styleSheet.textContent = `
  @keyframes slideOutNotification {
      from {
          opacity: 1;
          transform: translateX(0);
      }
      to {
          opacity: 0;
          transform: translateX(100%);
      }
  }
  
  @keyframes slideInNotification {
      from {
          opacity: 0;
          transform: translateX(100%);
      }
      to {
          opacity: 1;
          transform: translateX(0);
      }
  }
  
  @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
  }
  
  @keyframes fadeOut {
      from { opacity: 1; }
      to { opacity: 0; }
  }
  
  @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.7; }
  }
  
  @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
  }
  
  .notification {
      animation: slideInNotification 0.3s ease-out;
  }
  
  .loading-spinner {
      animation: spin 1s linear infinite;
  }
  
  .vehicle-item:hover {
      animation: none;
      transition: all 0.2s ease;
  }
  
  .btn:hover {
      animation: none;
      transition: all 0.2s ease;
  }
  
  .status-indicator {
      position: relative;
  }
  
  .status-indicator.connected::before {
      content: '';
      position: absolute;
      left: -10px;
      top: 50%;
      transform: translateY(-50%);
      width: 6px;
      height: 6px;
      background: #4CAF50;
      border-radius: 50%;
      animation: pulse 2s infinite;
  }
  
  .status-indicator.disconnected::before {
      content: '';
      position: absolute;
      left: -10px;
      top: 50%;
      transform: translateY(-50%);
      width: 6px;
      height: 6px;
      background: #f44336;
      border-radius: 50%;
  }
`;

document.head.appendChild(styleSheet);
