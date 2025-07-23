// Global variables
let currentTrailer = null;
let currentLocale = {};
let vehicleClasses = {};
let isLoading = false;

// DOM elements
const app = document.getElementById("app");
const loadingOverlay = document.getElementById("loading-overlay");
const loadingText = document.getElementById("loading-text");
const notificationContainer = document.getElementById("notification-container");

// Menu elements
const menuTitle = document.getElementById("menu-title");
const closeBtn = document.getElementById("close-btn");
const trailerModel = document.getElementById("trailer-model");
const trailerCapacity = document.getElementById("trailer-capacity");
const trailerLoaded = document.getElementById("trailer-loaded");

// Vehicle list elements
const loadedVehiclesList = document.getElementById("loaded-vehicles-list");
const availableVehiclesList = document.getElementById(
  "available-vehicles-list"
);
const vehicleSearch = document.getElementById("vehicle-search");
const classFilter = document.getElementById("class-filter");

// Initialize
document.addEventListener("DOMContentLoaded", function () {
  setupEventListeners();
  setupKeyBindings();
});

// Setup event listeners
function setupEventListeners() {
  closeBtn.addEventListener("click", closeMenu);
  vehicleSearch.addEventListener("input", filterVehicles);
  classFilter.addEventListener("change", filterVehicles);
}

// Setup key bindings
function setupKeyBindings() {
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
      closeMenu();
    }
  });
}

// NUI Message Handler
window.addEventListener("message", function (event) {
  const data = event.data;

  switch (data.type) {
    case "openMenu":
      openMenu(data);
      break;
    case "updateTrailer":
      updateTrailerInfo(data.trailer);
      break;
    case "showNotification":
      showNotification(data.message, data.type || "info");
      break;
    case "showLoading":
      showLoading(data.message);
      break;
    case "hideLoading":
      hideLoading();
      break;
  }
});

// Open menu
function openMenu(data) {
  currentTrailer = data.trailer;
  currentLocale = data.locale;
  vehicleClasses = data.vehicleClasses;

  updateLocalization();
  updateTrailerInfo(data.trailer);
  updateVehicleLists(data.trailer);
  populateClassFilter();

  app.classList.remove("hidden");
}

// Close menu
function closeMenu() {
  app.classList.add("hidden");
  currentTrailer = null;

  // Send close event to client
  fetch(`https://${GetParentResourceName()}/closeMenu`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });
}

// Update localization
function updateLocalization() {
  menuTitle.textContent = currentLocale.menu_title || "Vehicle Loader";

  // Update other localized elements as needed
  const elements = {
    "trailer-info-title": "vehicle_info",
    "loaded-vehicles-title": "loaded_vehicles",
    "available-vehicles-title": "available_vehicles",
  };

  Object.entries(elements).forEach(([id, key]) => {
    const element = document.getElementById(id);
    if (element && currentLocale[key]) {
      element.textContent = currentLocale[key];
    }
  });
}

// Update trailer information
function updateTrailerInfo(trailer) {
  if (!trailer) return;

  trailerModel.textContent = trailer.model.toUpperCase();
  trailerCapacity.textContent = `${trailer.loadedVehicles.length}/${trailer.config.maxVehicles}`;
  trailerLoaded.textContent = `${trailer.loadedVehicles.length} ${
    currentLocale.vehicles || "vehicles"
  }`;
}

// Update vehicle lists
function updateVehicleLists(trailer) {
  updateLoadedVehicles(trailer.loadedVehicles);
  updateAvailableVehicles(trailer.nearbyVehicles);
}

// Update loaded vehicles list
function updateLoadedVehicles(loadedVehicles) {
  loadedVehiclesList.innerHTML = "";

  if (!loadedVehicles || loadedVehicles.length === 0) {
    loadedVehiclesList.innerHTML = `
            <div class="empty-state">
                <p>${
                  currentLocale.no_vehicles_loaded || "No vehicles loaded"
                }</p>
            </div>
        `;
    return;
  }

  loadedVehicles.forEach((vehicle) => {
    const vehicleElement = createLoadedVehicleElement(vehicle);
    loadedVehiclesList.appendChild(vehicleElement);
  });
}

// Create loaded vehicle element
function createLoadedVehicleElement(vehicle) {
  const div = document.createElement("div");
  div.className = "vehicle-item loaded";
  div.innerHTML = `
        <div class="vehicle-info">
            <div class="vehicle-name">${vehicle.displayName}</div>
            <div class="vehicle-details">
                <span class="vehicle-class">${vehicle.className}</span>
                <span class="vehicle-slot">Slot ${vehicle.slot}</span>
            </div>
        </div>
        <button class="btn btn-unload" onclick="unloadVehicle(${vehicle.slot})">
            ${currentLocale.unload_vehicle || "Unload"}
        </button>
    `;
  return div;
}

// Update available vehicles list
function updateAvailableVehicles(availableVehicles) {
  availableVehiclesList.innerHTML = "";

  if (!availableVehicles || availableVehicles.length === 0) {
    availableVehiclesList.innerHTML = `
            <div class="empty-state">
                <p>${
                  currentLocale.no_vehicles_available || "No vehicles available"
                }</p>
            </div>
        `;
    return;
  }

  availableVehicles.forEach((vehicle) => {
    const vehicleElement = createAvailableVehicleElement(vehicle);
    availableVehiclesList.appendChild(vehicleElement);
  });
}

// Create available vehicle element
function createAvailableVehicleElement(vehicle) {
  const div = document.createElement("div");
  div.className = "vehicle-item";
  div.setAttribute("data-vehicle-name", vehicle.displayName.toLowerCase());
  div.setAttribute("data-vehicle-class", vehicle.class);

  div.innerHTML = `
        <div class="vehicle-info">
            <div class="vehicle-name">${vehicle.displayName}</div>
            <div class="vehicle-details">
                <span class="vehicle-class">${vehicle.className}</span>
                <span class="vehicle-distance">${Math.round(
                  vehicle.distance
                )}m</span>
            </div>
        </div>
        <button class="btn btn-load" onclick="loadVehicle(${vehicle.entity})">
            ${currentLocale.load_vehicle || "Load"}
        </button>
    `;
  return div;
}

// Populate class filter
function populateClassFilter() {
  classFilter.innerHTML = '<option value="">All Classes</option>';

  if (!currentTrailer || !currentTrailer.config.allowedClasses) return;

  currentTrailer.config.allowedClasses.forEach((classId) => {
    if (vehicleClasses[classId]) {
      const option = document.createElement("option");
      option.value = classId;
      option.textContent = vehicleClasses[classId];
      classFilter.appendChild(option);
    }
  });
}

// Filter vehicles
function filterVehicles() {
  const searchTerm = vehicleSearch.value.toLowerCase();
  const selectedClass = classFilter.value;

  const vehicleItems = availableVehiclesList.querySelectorAll(".vehicle-item");

  vehicleItems.forEach((item) => {
    const vehicleName = item.getAttribute("data-vehicle-name");
    const vehicleClass = item.getAttribute("data-vehicle-class");

    const matchesSearch = !searchTerm || vehicleName.includes(searchTerm);
    const matchesClass = !selectedClass || vehicleClass === selectedClass;

    if (matchesSearch && matchesClass) {
      item.style.display = "flex";
    } else {
      item.style.display = "none";
    }
  });

  // Check if any vehicles are visible
  const visibleVehicles = Array.from(vehicleItems).some(
    (item) => item.style.display !== "none"
  );

  if (!visibleVehicles && vehicleItems.length > 0) {
    if (!availableVehiclesList.querySelector(".no-results")) {
      const noResults = document.createElement("div");
      noResults.className = "empty-state no-results";
      noResults.innerHTML = "<p>No vehicles match your search criteria</p>";
      availableVehiclesList.appendChild(noResults);
    }
  } else {
    const noResults = availableVehiclesList.querySelector(".no-results");
    if (noResults) {
      noResults.remove();
    }
  }
}

// Load vehicle
function loadVehicle(vehicleId) {
  if (isLoading) return;

  isLoading = true;
  showLoading(currentLocale.loading_vehicle || "Loading vehicle...");

  fetch(`https://${GetParentResourceName()}/loadVehicle`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      vehicleId: vehicleId,
    }),
  })
    .then((response) => response.json())
    .then((data) => {
      hideLoading();
      isLoading = false;

      if (data.success) {
        showNotification(
          data.message ||
            currentLocale.vehicle_loaded ||
            "Vehicle loaded successfully",
          "success"
        );
        // Refresh menu data
        requestMenuUpdate();
      } else {
        showNotification(
          data.message ||
            currentLocale.loading_failed ||
            "Failed to load vehicle",
          "error"
        );
      }
    })
    .catch((error) => {
      hideLoading();
      isLoading = false;
      console.error("Load vehicle error:", error);
      showNotification(
        currentLocale.loading_failed || "Failed to load vehicle",
        "error"
      );
    });
}

// Unload vehicle
function unloadVehicle(slotIndex) {
  if (isLoading) return;

  isLoading = true;
  showLoading(currentLocale.unloading_vehicle || "Unloading vehicle...");

  fetch(`https://${GetParentResourceName()}/unloadVehicle`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      slotIndex: slotIndex,
    }),
  })
    .then((response) => response.json())
    .then((data) => {
      hideLoading();
      isLoading = false;

      if (data.success) {
        showNotification(
          data.message ||
            currentLocale.vehicle_unloaded ||
            "Vehicle unloaded successfully",
          "success"
        );
        // Refresh menu data
        requestMenuUpdate();
      } else {
        showNotification(
          data.message ||
            currentLocale.unloading_failed ||
            "Failed to unload vehicle",
          "error"
        );
      }
    })
    .catch((error) => {
      hideLoading();
      isLoading = false;
      console.error("Unload vehicle error:", error);
      showNotification(
        currentLocale.unloading_failed || "Failed to unload vehicle",
        "error"
      );
    });
}

// Request menu update
function requestMenuUpdate() {
  fetch(`https://${GetParentResourceName()}/requestUpdate`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  }).catch((error) => {
    console.error("Request update error:", error);
  });
}

// Show loading overlay
function showLoading(message = "Loading...") {
  loadingText.textContent = message;
  loadingOverlay.classList.remove("hidden");
}

// Hide loading overlay
function hideLoading() {
  loadingOverlay.classList.add("hidden");
}

// Show notification
function showNotification(message, type = "info", duration = 4000) {
  const notification = document.createElement("div");
  notification.className = `notification ${type}`;
  notification.textContent = message;

  notificationContainer.appendChild(notification);

  // Auto remove notification
  setTimeout(() => {
    if (notification.parentNode) {
      notification.style.animation =
        "slideOutNotification 0.3s ease-in forwards";
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 300);
    }
  }, duration);

  // Click to dismiss
  notification.addEventListener("click", () => {
    if (notification.parentNode) {
      notification.style.animation =
        "slideOutNotification 0.3s ease-in forwards";
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 300);
    }
  });
}

// Utility function to get parent resource name
function GetParentResourceName() {
  return window.location.hostname;
}

// CSS animation for notification slide out
const style = document.createElement("style");
style.textContent = `
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
`;
document.head.appendChild(style);

// Debug mode
if (window.location.search.includes("debug=true")) {
  console.log("Vehicle Loader UI Debug Mode Enabled");

  // Mock data for testing
  setTimeout(() => {
    const mockData = {
      type: "openMenu",
      trailer: {
        model: "tr2",
        config: {
          maxVehicles: 2,
          allowedClasses: [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12],
        },
        loadedVehicles: [
          {
            slot: 1,
            entity: 123,
            displayName: "Adder",
            class: 7,
            className: "Super",
          },
        ],
        nearbyVehicles: [
          {
            entity: 456,
            displayName: "Zentorno",
            class: 7,
            className: "Super",
            distance: 5.2,
          },
          {
            entity: 789,
            displayName: "Infernus",
            class: 7,
            className: "Super",
            distance: 8.7,
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

    window.dispatchEvent(new MessageEvent("message", { data: mockData }));
  }, 1000);
}
